//
//  SocialRecipePageExtractor.swift
//  RecipeImporting
//
//  Created by Tom Knighton on 21/05/2026.
//

import Foundation

struct SocialRecipePageContent: Sendable {
    var recipeText: String
    var imageURL: String?
}

enum SocialRecipePageExtractor {
    static func extractRecipeContent(from html: String) -> SocialRecipePageContent? {
        guard let recipeText = extractRecipeText(from: html) else {
            return nil
        }

        return SocialRecipePageContent(recipeText: recipeText, imageURL: extractImageURL(from: html))
    }

    static func extractRecipeText(from html: String) -> String? {
        let descriptions = extractedDescriptions(from: html)
        guard let bestDescription = descriptions.max(by: { score($0) < score($1) }) else {
            return nil
        }

        let normalized = normalize(bestDescription)
        guard hasRecipeStructure(in: normalized) else {
            return nil
        }

        return normalized
    }

    static func extractImageURL(from html: String) -> String? {
        let candidates = extractedImageCandidates(from: html)
        return candidates.max(by: { imageScore($0) < imageScore($1) })?.value
    }

    private static func extractedDescriptions(from html: String) -> [String] {
        var descriptions = metaDescriptions(from: html)

        if let json = universalDataJSON(from: html),
           let data = json.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            collectDescriptions(from: object, into: &descriptions)
        }

        return descriptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func extractedImageCandidates(from html: String) -> [(key: String, value: String)] {
        var candidates = metaImageURLs(from: html).map { (key: "meta", value: $0) }

        if let json = universalDataJSON(from: html),
           let data = json.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            collectImageURLs(from: object, into: &candidates)
        }

        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let value = decodedURLString(candidate.value)
            guard isValidImageURLString(value), seen.insert(value).inserted else {
                return nil
            }

            return (candidate.key, value)
        }
    }

    private static func metaDescriptions(from html: String) -> [String] {
        let patterns = [
            #"<meta\s+name="description"\s+content="([^"]*)""#,
            #"<meta\s+property="og:description"\s+content="([^"]*)""#,
            #"<meta\s+name="twitter:description"\s+content="([^"]*)""#
        ]

        return patterns.flatMap { matches(for: $0, in: html) }
            .map(decodeHTMLEntities)
    }

    private static func metaImageURLs(from html: String) -> [String] {
        let patterns = [
            #"<meta[^>]+(?:property|name)="(?:og:image:secure_url|og:image|twitter:image)"[^>]+content="([^"]+)""#,
            #"<meta[^>]+content="([^"]+)"[^>]+(?:property|name)="(?:og:image:secure_url|og:image|twitter:image)""#
        ]

        return patterns.flatMap { matches(for: $0, in: html) }
    }

    private static func universalDataJSON(from html: String) -> String? {
        matches(
            for: #"<script\s+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"\s+type="application/json">(.*?)</script>"#,
            in: html
        )
        .first
        .map(decodeHTMLEntities)
    }

    private static func collectDescriptions(from object: Any, into descriptions: inout [String]) {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if key == "desc" || key == "description",
                   let description = value as? String {
                    descriptions.append(description)
                }
                collectDescriptions(from: value, into: &descriptions)
            }
        } else if let array = object as? [Any] {
            for item in array {
                collectDescriptions(from: item, into: &descriptions)
            }
        }
    }

    private static func collectImageURLs(from object: Any, into candidates: inout [(key: String, value: String)]) {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if isImageKey(key), let value = value as? String {
                    candidates.append((key, value))
                }
                collectImageURLs(from: value, into: &candidates)
            }
        } else if let array = object as? [Any] {
            for item in array {
                collectImageURLs(from: item, into: &candidates)
            }
        }
    }

    private static func isImageKey(_ key: String) -> Bool {
        let lowered = key.lowercased()
        return lowered == "cover"
            || lowered == "origincover"
            || lowered == "dynamiccover"
            || lowered == "cover_url"
            || lowered == "thumbnailurl"
            || lowered == "thumbnail"
            || lowered == "image"
            || lowered == "imageurl"
    }

    private static func score(_ text: String) -> Int {
        let lowered = text.lowercased()
        var value = min(text.count / 20, 60)

        if lowered.contains("ingredient") { value += 100 }
        if lowered.contains("instruction") || lowered.contains("method") { value += 100 }
        if lowered.contains("recipe") { value += 30 }
        if lowered.contains(" likes,") || lowered.contains(" comments") { value -= 40 }

        return value
    }

    private static func imageScore(_ candidate: (key: String, value: String)) -> Int {
        let key = candidate.key.lowercased()
        let value = candidate.value.lowercased()
        var score = 0

        if key == "meta" { score += 40 }
        if key == "origincover" { score += 90 }
        if key == "cover" || key == "cover_url" { score += 80 }
        if key == "dynamiccover" { score += 60 }
        if value.contains("tiktokcdn") || value.contains("ttwstatic") || value.contains("cdninstagram") || value.contains("fbcdn") {
            score += 30
        }
        if value.contains("avt-") || value.contains("cropcenter") {
            score -= 60
        }
        if value.contains("video-share-card") {
            score += 20
        }

        return score
    }

    private static func normalize(_ text: String) -> String {
        let normalized = preparedCaptionText(from: text)
        let structured = structuredRecipeMarkdown(from: normalized)
        if structured != normalized {
            return structured
        }

        if let inlineStructured = structuredInlineRecipeMarkdown(from: normalized) {
            return inlineStructured
        }

        return promoteCaptionIntroToTitle(in: normalized)
    }

    private static func preparedCaptionText(from text: String) -> String {
        var normalized = decodeHTMLEntities(text)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "∙", with: "\n- ")
            .replacingOccurrences(of: "•", with: "\n- ")
            .replacingOccurrences(of: "·", with: "\n- ")
            .replacingOccurrences(of: "\t", with: " ")

        normalized = normalized.replacingOccurrences(
            of: #"(?is)^\s*[\d,.]+[KkMm]?\s+likes,\s*[\d,.]+[KkMm]?\s+comments\s+-\s*[^:]+:\s*"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?im)^\s*(ingredients?|ingredient list|you['’]?ll need|you will need|what you['’]?ll need|shopping list)\b[^\n]*$"#,
            with: "\n## Ingredients\n",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?im)^\s*(instructions|method|directions|steps|procedure)\b[^\n]*$"#,
            with: "\n## Instructions\n",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)(^|\s+)(ingredients?|ingredient list|you['’]?ll need|you will need|what you['’]?ll need|shopping list)\s*:?\s*(?=\n[-*+]\s|\d+\s|\d+[.)]\s)"#,
            with: "\n## Ingredients\n",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)(^|\s+)(instructions|method|directions|steps|procedure)\s*:?\s*(?=\d+[.)]\s)"#,
            with: "\n## Instructions\n",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"\s+(\d+)[.)]\s+"#,
            with: "\n$1. ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func structuredRecipeMarkdown(from text: String) -> String {
        enum Section {
            case title
            case ingredients
            case instructions
        }

        var section = Section.title
        var titleLines: [String] = []
        var ingredientLines: [String] = []
        var instructionLines: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = cleanedCaptionLine(rawLine)
            guard !line.isEmpty else { continue }

            if isIngredientHeading(line) {
                section = .ingredients
                continue
            }

            if isInstructionHeading(line) {
                section = .instructions
                continue
            }

            if section == .ingredients && looksLikeInstructionLine(line) {
                section = .instructions
            }

            switch section {
            case .title:
                titleLines.append(line)
            case .ingredients:
                ingredientLines.append(cleanedIngredientLine(strippedSocialListPrefix(from: line)))
            case .instructions:
                instructionLines.append(contentsOf: instructionSteps(from: strippedSocialListPrefix(from: line)))
            }
        }

        guard !ingredientLines.isEmpty || !instructionLines.isEmpty else {
            return text
        }

        var output: [String] = []
        let title = titleLines.first.map(captionTitle(from:))?.nilIfEmpty ?? "Imported Recipe"
        output.append("# \(title)")

        if !ingredientLines.isEmpty {
            output.append("\n## Ingredients")
            output.append(contentsOf: ingredientLines.map { "- \($0)" })
        }

        if !instructionLines.isEmpty {
            output.append("\n## Instructions")
            output.append(contentsOf: instructionLines.enumerated().map { index, step in "\(index + 1). \(step)" })
        }

        return output.joined(separator: "\n")
    }

    private static func structuredInlineRecipeMarkdown(from text: String) -> String? {
        guard let servingRange = text.range(
            of: #"(?i)\b(feeds|serves|makes)\s+\d[\d\s\-–]*(people|portions|servings)?"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let afterServing = text[servingRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let instructionRange = afterServing.range(
            of: #"(?i)\b(start by|heat|preheat|add|bake|blend|boil|chop|combine|cook|drain|fry|mix|place|pour|roll out|season|serve|simmer|stir|toss|whisk)\b"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let ingredientsText = afterServing[..<instructionRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let instructionsText = afterServing[instructionRange.lowerBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredientLines = inlineIngredientLines(from: ingredientsText)
        guard ingredientLines.count >= 3, !instructionsText.isEmpty else {
            return nil
        }

        let title = inlineRecipeTitle(from: String(text[..<servingRange.lowerBound]))
        let instructionLines = instructionSteps(from: instructionsText)
        guard !instructionLines.isEmpty else { return nil }

        var output = ["# \(title.nilIfEmpty ?? "Imported Recipe")", "", "## Ingredients"]
        output.append(contentsOf: ingredientLines.map { "- \($0)" })
        output.append("")
        output.append("## Instructions")
        output.append(contentsOf: instructionLines.enumerated().map { index, step in "\(index + 1). \(step)" })
        return output.joined(separator: "\n")
    }

    private static func inlineRecipeTitle(from text: String) -> String {
        let stripped = captionTitle(from: text)
        let markers = [
            " I ",
            " I’m ",
            " I'm ",
            " I’ve ",
            " I've ",
            " This ",
            " Back ",
            " Hot ",
            " Recipe "
        ]

        let earliestMarker = markers
            .compactMap { marker -> String.Index? in
                guard let range = stripped.range(of: marker), stripped.distance(from: stripped.startIndex, to: range.lowerBound) >= 8 else {
                    return nil
                }
                return range.lowerBound
            }
            .min()

        let title = if let earliestMarker {
            String(stripped[..<earliestMarker])
        } else if let sentenceEnd = stripped.firstIndex(of: ".") {
            String(stripped[..<sentenceEnd])
        } else {
            stripped
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inlineIngredientLines(from text: String) -> [String] {
        let separated = text
            .replacingOccurrences(
                of: #"(?i)\s+(?=(\d+([\/. -]\d+)?\s*(tbsp|tsp|cup|cups|g|kg|ml|l|oz|lb|lbs|large|small|medium|egg|eggs)\b|ground\s+|a\s+sheet\b|oil\s+for\b))"#,
                with: "\n",
                options: .regularExpression
            )

        return separated
            .components(separatedBy: .newlines)
            .map { cleanedIngredientLine(strippedSocialListPrefix(from: cleanedCaptionLine($0))) }
            .filter { !$0.isEmpty && !isHashtagRun($0) }
    }

    private static func isHashtagRun(_ line: String) -> Bool {
        let words = line.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return false }
        return words.allSatisfy { $0.hasPrefix("#") }
    }

    private static func cleanedCaptionLine(_ line: String) -> String {
        var cleaned = line
            .replacingOccurrences(of: #"^["'\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasSuffix("\".") || cleaned.hasSuffix("'.") {
            cleaned.removeLast(2)
            cleaned.append(".")
        }

        return cleaned
            .replacingOccurrences(of: #"["'\s]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func strippedSocialListPrefix(from line: String) -> String {
        line
            .replacingOccurrences(of: #"^[-*+]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+[.)]\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedIngredientLine(_ line: String) -> String {
        guard line.hasSuffix("."),
              looksLikeIngredientLine(String(line.dropLast())) else {
            return line
        }

        return String(line.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isIngredientHeading(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered == "## ingredients"
            || lowered == "ingredients"
            || lowered == "ingredient"
            || lowered == "ingredient list"
            || lowered == "you'll need"
            || lowered == "you’ll need"
            || lowered == "you will need"
            || lowered == "what you'll need"
            || lowered == "what you’ll need"
            || lowered == "shopping list"
            || lowered.range(of: #"^for\s+(the\s+)?.+:\s*$"#, options: .regularExpression) != nil
    }

    private static func isInstructionHeading(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered == "## instructions"
            || lowered == "instructions"
            || lowered == "method"
            || lowered == "directions"
            || lowered == "steps"
            || lowered == "procedure"
    }

    private static func looksLikeInstructionLine(_ line: String) -> Bool {
        let lowered = strippedSocialListPrefix(from: line).lowercased()
        if lowered.count > 80 {
            return cookingVerbs.contains { lowered.hasPrefix($0) || lowered.contains(". \($0)") }
        }

        return cookingVerbs.contains { lowered.hasPrefix($0) }
    }

    private static var cookingVerbs: [String] {
        ["add", "bake", "blend", "boil", "chop", "combine", "cook", "drain", "fry", "heat", "mix", "pour", "preheat", "rinse", "season", "serve", "simmer", "stir", "toss", "whisk"]
    }

    private static func hasRecipeStructure(in text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("ingredient")
            || lowered.contains("instruction")
            || lowered.contains("method") {
            return true
        }

        let lines = text.components(separatedBy: .newlines).map(cleanedCaptionLine)
        guard lines.contains(where: isIngredientHeading) else {
            return false
        }

        return lines.contains { line in
            let stripped = strippedSocialListPrefix(from: line)
            return looksLikeIngredientLine(stripped)
        }
    }

    private static func looksLikeIngredientLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.range(of: #"^\d+([\/. -]\d+)?\s*(tsp|tbsp|cup|cups|g|kg|ml|l|oz|lb|lbs)\b"#, options: .regularExpression) != nil {
            return true
        }
        if lowered.range(of: #"^\d+\s*(clove|cloves|can|cans)\b"#, options: .regularExpression) != nil {
            return true
        }
        return lowered.range(of: #"\b(salt|pepper|paprika|cumin|thyme|garlic|onion|pasta|cream|cheese|tomatoes|broth|sausage)\b"#, options: .regularExpression) != nil
    }

    private static func instructionSteps(from line: String) -> [String] {
        guard line.count > 120 else { return [line] }

        let parts = line
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard parts.count > 1 else { return [line] }
        return parts.map { part in
            part.hasSuffix(".") ? part : "\(part)."
        }
    }

    private static func matches(for pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private static func promoteCaptionIntroToTitle(in text: String) -> String {
        guard !text.hasPrefix("#") else { return text }

        let headingRanges = [
            text.range(of: "## Ingredients"),
            text.range(of: "## Instructions")
        ].compactMap(\.self)

        guard let firstHeading = headingRanges.min(by: { $0.lowerBound < $1.lowerBound }) else {
            return text
        }

        let intro = text[..<firstHeading.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intro.isEmpty else { return text }

        let body = text[firstHeading.lowerBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "# \(captionTitle(from: String(intro)))\n\n\(body)"
    }

    private static func captionTitle(from intro: String) -> String {
        intro
            .replacingOccurrences(of: #"(?i)\s+#\w+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodedURLString(_ text: String) -> String {
        decodeHTMLEntities(text)
            .replacingOccurrences(of: #"\\u002F"#, with: "/", options: .regularExpression)
            .replacingOccurrences(of: #"\/"#, with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidImageURLString(_ text: String) -> Bool {
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased() else {
            return false
        }

        return host.contains("tiktok")
            || host.contains("ttwstatic")
            || host.contains("muscdn")
            || host.contains("instagram")
            || host.contains("fbcdn")
            || text.localizedCaseInsensitiveContains(".jpg")
            || text.localizedCaseInsensitiveContains(".jpeg")
            || text.localizedCaseInsensitiveContains(".png")
            || text.localizedCaseInsensitiveContains(".webp")
            || text.localizedCaseInsensitiveContains(".image")
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        decodeNumericHTMLEntities(in: text)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func decodeNumericHTMLEntities(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);"#) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var decoded = text
        for match in regex.matches(in: text, range: range).reversed() {
            guard let wholeRange = Range(match.range(at: 0), in: decoded),
                  let numberRange = Range(match.range(at: 1), in: decoded) else {
                continue
            }

            let number = decoded[numberRange]
            let radix = number.hasPrefix("x") || number.hasPrefix("X") ? 16 : 10
            let digits = number.dropFirst(radix == 16 ? 1 : 0)
            guard let scalarValue = UInt32(digits, radix: radix),
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }

            decoded.replaceSubrange(wholeRange, with: String(Character(scalar)))
        }

        return decoded
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
