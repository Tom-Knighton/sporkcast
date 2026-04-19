import Foundation

struct ShoppingListParsedItemTitle {
    let normalizedMergeKey: String
    let suffix: String
    let quantity: Double
    let hasExplicitQuantity: Bool
    let fallbackTitle: String
}

enum ShoppingListItemQuantityMerger {
    static let quantityPrefixRegex = try! NSRegularExpression(
        pattern: #"^((?:\d+\s+\d+\s*/\s*\d+)|(?:\d+\s*/\s*\d+)|(?:\d+(?:[.,]\d+)?)|(?:[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒]))"#,
        options: []
    )

    static func parsedTitle(_ title: String) -> ShoppingListParsedItemTitle {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ShoppingListParsedItemTitle(
                normalizedMergeKey: "",
                suffix: "",
                quantity: 1,
                hasExplicitQuantity: false,
                fallbackTitle: ""
            )
        }

        let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        if let match = quantityPrefixRegex.firstMatch(in: trimmed, options: [], range: fullRange),
           let quantityRange = Range(match.range(at: 1), in: trimmed) {
            let quantityText = String(trimmed[quantityRange])
            if let quantity = quantityValue(from: quantityText) {
                let suffix = String(trimmed[quantityRange.upperBound...])
                let normalizedMergeKey = normalizeMergeKey(suffix)
                if !normalizedMergeKey.isEmpty {
                    return ShoppingListParsedItemTitle(
                        normalizedMergeKey: normalizedMergeKey,
                        suffix: suffix,
                        quantity: quantity,
                        hasExplicitQuantity: true,
                        fallbackTitle: trimmed
                    )
                }
            }
        }

        return ShoppingListParsedItemTitle(
            normalizedMergeKey: normalizeMergeKey(trimmed),
            suffix: " \(trimmed)",
            quantity: 1,
            hasExplicitQuantity: false,
            fallbackTitle: trimmed
        )
    }

    static func mergedTitle(existing: String, incoming: String) -> String {
        let existingParsed = parsedTitle(existing)
        let incomingParsed = parsedTitle(incoming)
        let totalQuantity = existingParsed.quantity + incomingParsed.quantity
        let suffix = existingParsed.suffix.isEmpty ? incomingParsed.suffix : existingParsed.suffix
        let shouldShowQuantity =
            existingParsed.hasExplicitQuantity ||
            incomingParsed.hasExplicitQuantity ||
            totalQuantity > 1

        guard shouldShowQuantity else {
            return existingParsed.fallbackTitle
        }

        if suffix.isEmpty {
            return formatQuantity(totalQuantity)
        }

        return "\(formatQuantity(totalQuantity))\(suffix)"
    }

    static func normalizeMergeKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let withoutMultiplierPrefix = trimmed.replacingOccurrences(
            of: #"^(?:x|×)\s*"#,
            with: "",
            options: .regularExpression
        )

        return withoutMultiplierPrefix
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func quantityValue(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let unicodeFractions: [String: Double] = [
            "½": 0.5,
            "⅓": 1.0 / 3.0,
            "⅔": 2.0 / 3.0,
            "¼": 0.25,
            "¾": 0.75,
            "⅕": 0.2,
            "⅖": 0.4,
            "⅗": 0.6,
            "⅘": 0.8,
            "⅙": 1.0 / 6.0,
            "⅚": 5.0 / 6.0,
            "⅐": 1.0 / 7.0,
            "⅛": 0.125,
            "⅜": 0.375,
            "⅝": 0.625,
            "⅞": 0.875,
            "⅑": 1.0 / 9.0,
            "⅒": 0.1
        ]

        if let mapped = unicodeFractions[trimmed] {
            return mapped
        }

        if trimmed.contains("/") {
            let compact = trimmed.replacingOccurrences(of: "\\s*/\\s*", with: "/", options: .regularExpression)
            let mixedParts = compact.split(separator: " ")

            if mixedParts.count == 2,
               let whole = Double(mixedParts[0]),
               let fraction = fractionValue(from: String(mixedParts[1])) {
                return whole + fraction
            }

            return fractionValue(from: compact)
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    static func fractionValue(from text: String) -> Double? {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0 else {
            return nil
        }

        return numerator / denominator
    }

    static func formatQuantity(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }

        return String(format: "%.3f", rounded)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}
