//
//  RecipeImportJSONAdapters.swift
//  RecipeImporting
//
//  Created by Tom Knighton on 01/04/2026.
//

import Foundation

protocol RecipeImportJSONAdapting {
    var vendor: RecipeImportVendor { get }
    func parse(jsonObject: Any) -> [ImportedRecipeRecord]
}

enum RecipeImportJSONAdapterRegistry {
    static func orderedAdapters(preferredVendor: RecipeImportVendor) -> [any RecipeImportJSONAdapting] {
        let sporkcast = SporkastJSONImportAdapter()
        let pestle = PestleJSONImportAdapter()
        let crouton = CroutonJSONImportAdapter()
        let paprika = PaprikaJSONImportAdapter()
        let generic = GenericJSONImportAdapter()

        switch preferredVendor {
        case .sporkcast:
            return [sporkcast, generic]
        case .pestle:
            return [pestle, generic]
        case .crouton:
            return [crouton, generic]
        case .paprika:
            return [paprika, generic]
        default:
            return [sporkcast, pestle, crouton, paprika, generic]
        }
    }
}

private struct SporkastJSONImportAdapter: RecipeImportJSONAdapting {
    let vendor: RecipeImportVendor = .sporkcast

    func parse(jsonObject: Any) -> [ImportedRecipeRecord] {
        let payloads: [[String: Any]]
        if let payloadArray = jsonObject as? [[String: Any]] {
            payloads = payloadArray
        } else if let payload = jsonObject as? [String: Any] {
            payloads = [payload]
        } else {
            return []
        }

        return payloads.compactMap(parsePayload)
    }

    private func parsePayload(_ payload: [String: Any]) -> ImportedRecipeRecord? {
        guard let recipe = payload["recipe"] as? [String: Any] else {
            return nil
        }

        let title = RecipeImportJSONSupport
            .stringValue(for: ["title", "name"], in: recipe)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title, !title.isEmpty else {
            return nil
        }

        let ingredientGroups = (payload["ingredientGroups"] as? [[String: Any]] ?? [])
            .sorted(by: groupSortOrder)
        let ingredients = (payload["ingredients"] as? [[String: Any]] ?? [])
            .sorted(by: lineSortOrder)
        let stepGroups = (payload["stepGroups"] as? [[String: Any]] ?? [])
            .sorted(by: groupSortOrder)
        let steps = (payload["steps"] as? [[String: Any]] ?? [])
            .sorted(by: lineSortOrder)

        let ingredientSections = makeIngredientSections(groups: ingredientGroups, ingredients: ingredients)
        let stepSections = makeStepSections(groups: stepGroups, steps: steps)
        let image = parseImage(from: payload["image"])
        let ratings = parseRatings(from: payload["ratings"])

        return ImportedRecipeRecord(
            title: title,
            description: RecipeImportJSONSupport.stringValue(for: ["description"], in: recipe),
            author: RecipeImportJSONSupport.stringValue(for: ["author"], in: recipe),
            sourceURL: RecipeImportJSONSupport.stringValue(for: ["sourceUrl", "source_url", "url"], in: recipe),
            imageURL: image.url,
            imageData: image.data,
            serves: RecipeImportJSONSupport.stringValue(for: ["serves"], in: recipe),
            prepMinutes: RecipeImportJSONSupport.numericValue(for: ["minutesToPrepare"], in: recipe),
            cookMinutes: RecipeImportJSONSupport.numericValue(for: ["minutesToCook"], in: recipe),
            totalMinutes: RecipeImportJSONSupport.numericValue(for: ["totalMins"], in: recipe),
            overallRating: RecipeImportJSONSupport.numericValue(for: ["overallRating"], in: recipe),
            totalRatings: RecipeImportJSONSupport.intValue(for: ["totalRatings"], in: recipe),
            summarisedRating: RecipeImportJSONSupport.stringValue(for: ["summarisedRating"], in: recipe),
            ratings: ratings,
            ingredientSections: ingredientSections,
            stepSections: stepSections
        )
    }

    private func makeIngredientSections(
        groups: [[String: Any]],
        ingredients: [[String: Any]]
    ) -> [ImportedIngredientSection] {
        guard !groups.isEmpty else {
            let lines = ingredients.compactMap { RecipeImportJSONSupport.stringValue(for: ["rawIngredient"], in: $0) }
            return lines.isEmpty ? [] : [ImportedIngredientSection(title: "Ingredients", ingredients: lines)]
        }

        let ingredientsByGroup = Dictionary(grouping: ingredients) { RecipeImportJSONSupport.idString(for: ["ingredientGroupId"], in: $0) ?? "" }
        return groups.compactMap { group in
            guard let groupID = RecipeImportJSONSupport.idString(for: ["id"], in: group) else {
                return nil
            }

            let lines = (ingredientsByGroup[groupID] ?? [])
                .sorted(by: lineSortOrder)
                .compactMap { RecipeImportJSONSupport.stringValue(for: ["rawIngredient"], in: $0) }
            return ImportedIngredientSection(
                title: RecipeImportJSONSupport.stringValue(for: ["title"], in: group) ?? "Ingredients",
                ingredients: lines
            )
        }
    }

    private func makeStepSections(
        groups: [[String: Any]],
        steps: [[String: Any]]
    ) -> [ImportedStepSection] {
        guard !groups.isEmpty else {
            let lines = steps.compactMap { RecipeImportJSONSupport.stringValue(for: ["instruction"], in: $0) }
            return lines.isEmpty ? [] : [ImportedStepSection(title: "Method", steps: lines)]
        }

        let stepsByGroup = Dictionary(grouping: steps) { RecipeImportJSONSupport.idString(for: ["groupId"], in: $0) ?? "" }
        return groups.compactMap { group in
            guard let groupID = RecipeImportJSONSupport.idString(for: ["id"], in: group) else {
                return nil
            }

            let lines = (stepsByGroup[groupID] ?? [])
                .sorted(by: lineSortOrder)
                .compactMap { RecipeImportJSONSupport.stringValue(for: ["instruction"], in: $0) }
            return ImportedStepSection(
                title: RecipeImportJSONSupport.stringValue(for: ["title"], in: group) ?? "Method",
                steps: lines
            )
        }
    }

    private func parseImage(from rawImage: Any?) -> (url: String?, data: Data?) {
        guard let imageDict = rawImage as? [String: Any] else {
            return (nil, nil)
        }

        let imageURL = RecipeImportJSONSupport.stringValue(for: ["imageSourceUrl", "image_url", "url"], in: imageDict)
        let imageData = RecipeImportJSONSupport.dataValue(for: ["imageData"], in: imageDict)
        return (imageURL, imageData)
    }

    private func parseRatings(from rawRatings: Any?) -> [ImportedRecipeRating] {
        guard let ratings = rawRatings as? [[String: Any]] else {
            return []
        }

        return ratings.compactMap { rating in
            let parsedRating = RecipeImportJSONSupport.intValue(for: ["rating"], in: rating)
            let parsedComment = RecipeImportJSONSupport.stringValue(for: ["comment"], in: rating)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ratingID: UUID?
            if let idString = RecipeImportJSONSupport.idString(for: ["id"], in: rating) {
                ratingID = UUID(uuidString: idString)
            } else {
                ratingID = nil
            }

            let hasComment = !(parsedComment?.isEmpty ?? true)
            guard parsedRating != nil || hasComment else {
                return nil
            }

            return ImportedRecipeRating(
                id: ratingID,
                rating: parsedRating,
                comment: hasComment ? parsedComment : nil
            )
        }
    }

    private func groupSortOrder(lhs: [String: Any], rhs: [String: Any]) -> Bool {
        let lhsSort = RecipeImportJSONSupport.intValue(for: ["sortIndex"], in: lhs) ?? .max
        let rhsSort = RecipeImportJSONSupport.intValue(for: ["sortIndex"], in: rhs) ?? .max
        if lhsSort != rhsSort {
            return lhsSort < rhsSort
        }

        let lhsID = RecipeImportJSONSupport.idString(for: ["id"], in: lhs) ?? ""
        let rhsID = RecipeImportJSONSupport.idString(for: ["id"], in: rhs) ?? ""
        return lhsID < rhsID
    }

    private func lineSortOrder(lhs: [String: Any], rhs: [String: Any]) -> Bool {
        let lhsSort = RecipeImportJSONSupport.intValue(for: ["sortIndex"], in: lhs) ?? .max
        let rhsSort = RecipeImportJSONSupport.intValue(for: ["sortIndex"], in: rhs) ?? .max
        if lhsSort != rhsSort {
            return lhsSort < rhsSort
        }

        let lhsID = RecipeImportJSONSupport.idString(for: ["id"], in: lhs) ?? ""
        let rhsID = RecipeImportJSONSupport.idString(for: ["id"], in: rhs) ?? ""
        return lhsID < rhsID
    }
}

private struct GenericJSONImportAdapter: RecipeImportJSONAdapting {
    let vendor: RecipeImportVendor = .unknown

    func parse(jsonObject: Any) -> [ImportedRecipeRecord] {
        let dictionaries = RecipeImportJSONSupport.extractRecipeObjects(
            from: jsonObject,
            collectionKeys: ["recipes", "recipe_list", "items"],
            singleRecipeKeys: ["recipe"]
        )

        return dictionaries.compactMap {
            RecipeImportJSONSupport.makeRecord(
                from: $0,
                titleKeys: ["title", "name", "recipeName", "recipe_title"],
                descriptionKeys: ["description", "summary", "notes"],
                authorKeys: ["author", "source_name", "creator"],
                sourceURLKeys: ["url", "source_url", "source", "site"],
                imageURLKeys: ["image", "image_url", "photo_url", "photo"],
                servesKeys: ["serves", "servings", "yield", "yield_text"],
                prepMinutesKeys: ["prepTime", "prep_time", "prep_minutes", "prep"],
                cookMinutesKeys: ["cookTime", "cook_time", "cook_minutes", "cook"],
                totalMinutesKeys: ["totalTime", "total_time", "total_minutes"],
                ingredientKeys: ["ingredients", "ingredient_lines", "ingredientLines", "ingredient_list"],
                stepKeys: ["instructions", "directions", "method", "steps"]
            )
        }
    }
}

private struct PestleJSONImportAdapter: RecipeImportJSONAdapting {
    let vendor: RecipeImportVendor = .pestle

    func parse(jsonObject: Any) -> [ImportedRecipeRecord] {
        let dictionaries = RecipeImportJSONSupport.extractRecipeObjects(
            from: jsonObject,
            collectionKeys: ["recipes", "items", "recipe_list", "data"],
            singleRecipeKeys: ["recipe"]
        )

        return dictionaries.compactMap {
            RecipeImportJSONSupport.makeRecord(
                from: $0,
                titleKeys: ["name", "title", "recipeName"],
                descriptionKeys: ["description", "note", "notes", "summary"],
                authorKeys: ["author", "creator", "source_name"],
                sourceURLKeys: ["source", "source_url", "sourceUrl", "url"],
                imageURLKeys: ["image_url", "image", "photo", "photo_url"],
                servesKeys: ["recipeYield", "servings", "serves", "yield"],
                prepMinutesKeys: ["prep_time", "prepTime", "prep_minutes"],
                cookMinutesKeys: ["cook_time", "cookTime", "cook_minutes"],
                totalMinutesKeys: ["total_time", "totalTime", "total_minutes"],
                ingredientKeys: ["recipeIngredient", "ingredients", "ingredient_lines", "ingredientLines", "ingredient_sections"],
                stepKeys: ["recipeInstructions", "instructions", "directions", "method", "steps"]
            )
        }
    }
}

private struct CroutonJSONImportAdapter: RecipeImportJSONAdapting {
    let vendor: RecipeImportVendor = .crouton

    func parse(jsonObject: Any) -> [ImportedRecipeRecord] {
        let dictionaries = RecipeImportJSONSupport.extractRecipeObjects(
            from: jsonObject,
            collectionKeys: ["recipes", "items", "recipe_list", "data"],
            singleRecipeKeys: ["recipe"]
        )

        return dictionaries.compactMap {
            RecipeImportJSONSupport.makeRecord(
                from: $0,
                titleKeys: ["title", "name", "recipe_title"],
                descriptionKeys: ["description", "notes", "summary"],
                authorKeys: ["author", "creator", "source_name", "sourceName"],
                sourceURLKeys: ["webLink", "url", "source", "source_url"],
                imageURLKeys: ["images", "sourceImage", "image", "image_url", "photo_url"],
                servesKeys: ["servings", "serves", "yield"],
                prepMinutesKeys: ["duration", "prep_minutes", "prep_time", "prepTime"],
                cookMinutesKeys: ["cookingDuration", "cook_minutes", "cook_time", "cookTime"],
                totalMinutesKeys: ["totalDuration", "total_minutes", "total_time", "totalTime"],
                ingredientKeys: ["ingredients", "ingredient_sections", "ingredientSections", "ingredient_lines"],
                stepKeys: ["steps", "instructions", "directions", "method"]
            )
        }
    }
}

private struct PaprikaJSONImportAdapter: RecipeImportJSONAdapting {
    let vendor: RecipeImportVendor = .paprika

    func parse(jsonObject: Any) -> [ImportedRecipeRecord] {
        let dictionaries = RecipeImportJSONSupport.extractRecipeObjects(
            from: jsonObject,
            collectionKeys: ["recipes", "items", "data"],
            singleRecipeKeys: ["recipe"]
        )

        return dictionaries.compactMap {
            RecipeImportJSONSupport.makeRecord(
                from: $0,
                titleKeys: ["name", "title"],
                descriptionKeys: ["description", "notes"],
                authorKeys: ["author", "source_name", "source"],
                sourceURLKeys: ["source_url", "source", "url"],
                imageURLKeys: ["photo_url", "photo", "image_url", "image"],
                servesKeys: ["servings", "yield", "serves"],
                prepMinutesKeys: ["prep_time", "prepTime", "prep_minutes"],
                cookMinutesKeys: ["cook_time", "cookTime", "cook_minutes"],
                totalMinutesKeys: ["total_time", "totalTime", "total_minutes"],
                ingredientKeys: ["ingredients", "ingredient_lines", "ingredientLines"],
                stepKeys: ["directions", "instructions", "method", "steps"]
            )
        }
    }
}

private enum RecipeImportJSONSupport {
    static func extractRecipeObjects(
        from object: Any,
        collectionKeys: [String],
        singleRecipeKeys: [String]
    ) -> [[String: Any]] {
        if let array = object as? [[String: Any]] {
            return array
        }

        guard let dict = object as? [String: Any] else {
            return []
        }

        if let nested = dictionaryValue(for: collectionKeys, in: dict) as? [[String: Any]] {
            return nested
        }

        if let nestedAny = dictionaryValue(for: collectionKeys, in: dict) as? [Any] {
            return nestedAny.compactMap { $0 as? [String: Any] }
        }

        if let single = dictionaryValue(for: singleRecipeKeys, in: dict) as? [String: Any] {
            return [single]
        }

        return [dict]
    }

    static func makeRecord(
        from dict: [String: Any],
        titleKeys: [String],
        descriptionKeys: [String],
        authorKeys: [String],
        sourceURLKeys: [String],
        imageURLKeys: [String],
        servesKeys: [String],
        prepMinutesKeys: [String],
        cookMinutesKeys: [String],
        totalMinutesKeys: [String],
        ingredientKeys: [String],
        stepKeys: [String]
    ) -> ImportedRecipeRecord? {
        let title = stringValue(for: titleKeys, in: dict)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let title, !title.isEmpty else { return nil }

        let ingredientLines = lineList(for: ingredientKeys, in: dict)
        let stepLines = lineList(for: stepKeys, in: dict)
        let image = parseImageFields(for: imageURLKeys, in: dict)

        return ImportedRecipeRecord(
            title: title,
            description: stringValue(for: descriptionKeys, in: dict),
            author: stringValue(for: authorKeys, in: dict),
            sourceURL: stringValue(for: sourceURLKeys, in: dict),
            imageURL: image.url,
            imageData: image.data,
            serves: stringValue(for: servesKeys, in: dict),
            prepMinutes: numericValue(for: prepMinutesKeys, in: dict),
            cookMinutes: numericValue(for: cookMinutesKeys, in: dict),
            totalMinutes: numericValue(for: totalMinutesKeys, in: dict),
            ingredientSections: [ImportedIngredientSection(title: "Ingredients", ingredients: ingredientLines)],
            stepSections: [ImportedStepSection(title: "Method", steps: stepLines)]
        )
    }

    static func lineList(for keys: [String], in dict: [String: Any]) -> [String] {
        for key in keys {
            if let value = dictionaryValue(for: [key], in: dict) {
                let normalized = normalizeLineList(value)
                if !normalized.isEmpty {
                    return normalized
                }
            }
        }

        return []
    }

    static func dictionaryValue(for keys: [String], in dict: [String: Any]) -> Any? {
        for key in keys {
            if let value = dict[key] {
                return value
            }

            if let match = dict.first(where: { normalizeKey($0.key) == normalizeKey(key) }) {
                return match.value
            }
        }

        return nil
    }

    static func stringValue(for keys: [String], in dict: [String: Any]) -> String? {
        guard let value = dictionaryValue(for: keys, in: dict) else { return nil }
        return stringValue(from: value)
    }

    static func idString(for keys: [String], in dict: [String: Any]) -> String? {
        guard let value = dictionaryValue(for: keys, in: dict) else { return nil }
        if let string = value as? String {
            return string
        }
        if let uuid = value as? UUID {
            return uuid.uuidString
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    static func intValue(for keys: [String], in dict: [String: Any]) -> Int? {
        guard let value = dictionaryValue(for: keys, in: dict) else { return nil }
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    static func dataValue(for keys: [String], in dict: [String: Any]) -> Data? {
        guard let value = dictionaryValue(for: keys, in: dict) else { return nil }
        if let data = value as? Data {
            return data
        }
        if let base64 = value as? String {
            return Data(base64Encoded: base64, options: [.ignoreUnknownCharacters])
        }
        return nil
    }

    private static func stringValue(from value: Any) -> String? {
        if let string = value as? String {
            return string
        }

        if let int = value as? Int {
            return String(int)
        }

        if let double = value as? Double {
            return String(double)
        }

        if let dict = value as? [String: Any] {
            for key in ["url", "name", "text", "value", "src", "amount", "quantityType", "title"] {
                if let nested = dictionaryValue(for: [key], in: dict),
                   let resolved = stringValue(from: nested)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !resolved.isEmpty {
                    return resolved
                }
            }
        }

        if let array = value as? [Any] {
            for element in array {
                if let resolved = stringValue(from: element)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !resolved.isEmpty {
                    return resolved
                }
            }
        }

        return nil
    }

    static func numericValue(for keys: [String], in dict: [String: Any]) -> Double? {
        guard let value = dictionaryValue(for: keys, in: dict) else { return nil }

        if let double = value as? Double {
            return double
        }

        if let int = value as? Int {
            return Double(int)
        }

        if let string = value as? String {
            if let isoDurationMinutes = parseISO8601DurationMinutes(from: string) {
                return isoDurationMinutes
            }
            return parseLeadingNumber(from: string)
        }

        return nil
    }

    static func parseImageFields(for keys: [String], in dict: [String: Any]) -> (url: String?, data: Data?) {
        for key in keys {
            guard let raw = dictionaryValue(for: [key], in: dict) else { continue }
            if let parsed = parseImageField(raw) {
                return parsed
            }
        }

        return (nil, nil)
    }

    private static func parseImageField(_ raw: Any) -> (url: String?, data: Data?)? {
        if let string = raw as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if let webURL = parseExternalWebURL(trimmed) {
                return (webURL, nil)
            }

            if let dataURLDecoded = decodeDataURLImage(trimmed),
               looksLikeImageData(dataURLDecoded) {
                return (nil, dataURLDecoded)
            }

            if let base64 = Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters]),
               looksLikeImageData(base64) {
                return (nil, base64)
            }

            return nil
        }

        if let array = raw as? [Any] {
            for element in array {
                if let parsed = parseImageField(element) {
                    return parsed
                }
            }
            return nil
        }

        if let dict = raw as? [String: Any] {
            for key in ["url", "src", "image", "value", "data"] {
                if let nested = dictionaryValue(for: [key], in: dict),
                   let parsed = parseImageField(nested) {
                    return parsed
                }
            }
            return nil
        }

        return nil
    }

    private static func parseExternalWebURL(_ candidate: String) -> String? {
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url.absoluteString
    }

    private static func decodeDataURLImage(_ value: String) -> Data? {
        let lowered = value.lowercased()
        guard lowered.hasPrefix("data:image"),
              let commaIndex = value.firstIndex(of: ",") else {
            return nil
        }
        let encoded = String(value[value.index(after: commaIndex)...])
        return Data(base64Encoded: encoded, options: [.ignoreUnknownCharacters])
    }

    private static func looksLikeImageData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }

        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return true // JPEG
        }
        if bytes.count >= 4, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return true // PNG
        }
        if bytes.count >= 4, bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x38 {
            return true // GIF
        }
        if bytes.count >= 12,
           bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
           bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
            return true // WEBP
        }

        return false
    }

    static func normalizeLineList(_ raw: Any) -> [String] {
        if let string = raw as? String {
            return string
                .replacingOccurrences(of: "\r\n", with: "\n")
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let array = raw as? [String] {
            return array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let array = raw as? [Any] {
            return array
                .flatMap { normalizeLineElement($0) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    private static func normalizeLineElement(_ element: Any) -> [String] {
        if let string = element as? String {
            return [string]
        }

        guard let dict = element as? [String: Any] else {
            return []
        }

        if let nested = dictionaryValue(for: ["ingredients", "steps", "items", "instructions", "directions", "itemListElement"], in: dict) {
            let nestedLines = normalizeLineList(nested)
            if !nestedLines.isEmpty {
                return nestedLines
            }
        }

        let quantity = stringValue(for: ["quantity", "amount"], in: dict) ?? ""
        var unit = stringValue(for: ["unit", "unitText", "quantityType"], in: dict) ?? ""
        if unit.isEmpty,
           let quantityDict = dict["quantity"] as? [String: Any] {
            unit = stringValue(for: ["quantityType", "unit", "unitText"], in: quantityDict) ?? ""
        }
        unit = normalizeUnitToken(unit)
        let name = stringValue(for: ["name", "ingredient", "item", "text"], in: dict) ?? ""

        if !name.isEmpty, (!quantity.isEmpty || !unit.isEmpty) {
            let joined = [quantity, unit, name]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return joined.isEmpty ? [] : [joined]
        }

        if let explicit = stringValue(for: ["text", "name", "ingredient", "instruction", "step"], in: dict),
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [explicit]
        }

        let joined = [quantity, unit, name]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return joined.isEmpty ? [] : [joined]
    }

    private static func normalizeUnitToken(_ rawUnit: String) -> String {
        let normalized = rawUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        switch normalized.uppercased() {
        case "ITEM", "NONE":
            return ""
        case "GRAM", "GRAMS", "G":
            return "g"
        case "KILOGRAM", "KILOGRAMS", "KG":
            return "kg"
        case "MILL", "MILLS", "MILLILITRE", "MILLILITER", "MILLILITRES", "MILLILITERS", "ML":
            return "ml"
        case "LITRE", "LITER", "LITRES", "LITERS", "L":
            return "l"
        case "TEASPOON", "TEASPOONS", "TSP":
            return "tsp"
        case "TABLESPOON", "TABLESPOONS", "TBSP":
            return "tbsp"
        case "CUP", "CUPS":
            return "cup"
        case "POUND", "POUNDS", "LB", "LBS":
            return "lb"
        case "OUNCE", "OUNCES", "OZ":
            return "oz"
        case "PINCH", "PINCHES":
            return "pinch"
        case "CLOVE", "CLOVES":
            return "clove"
        case "SLICE", "SLICES":
            return "slice"
        case "CAN", "CANS":
            return "can"
        default:
            return normalized.lowercased()
        }
    }

    private static func parseLeadingNumber(from string: String) -> Double? {
        if let direct = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return direct
        }

        let pattern = "([0-9]+(?:\\.[0-9]+)?)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: string.utf16.count)
        if let match = regex?.firstMatch(in: string, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: string) {
            return Double(String(string[matchRange]))
        }

        return nil
    }

    private static func parseISO8601DurationMinutes(from string: String) -> Double? {
        let uppercase = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard uppercase.hasPrefix("P") else { return nil }

        var totalMinutes = 0.0

        if let days = captureDurationComponent("([0-9]+(?:\\.[0-9]+)?)D", in: uppercase) {
            totalMinutes += days * 24 * 60
        }
        if let hours = captureDurationComponent("([0-9]+(?:\\.[0-9]+)?)H", in: uppercase) {
            totalMinutes += hours * 60
        }
        if let minutes = captureDurationComponent("([0-9]+(?:\\.[0-9]+)?)M", in: uppercase) {
            totalMinutes += minutes
        }
        if let seconds = captureDurationComponent("([0-9]+(?:\\.[0-9]+)?)S", in: uppercase) {
            totalMinutes += seconds / 60
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }

    private static func captureDurationComponent(_ pattern: String, in source: String) -> Double? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: source.utf16.count)
        guard let match = regex?.firstMatch(in: source, options: [], range: range),
              let matchRange = Range(match.range(at: 1), in: source) else {
            return nil
        }
        return Double(String(source[matchRange]))
    }

    private static func normalizeKey(_ key: String) -> String {
        key
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
