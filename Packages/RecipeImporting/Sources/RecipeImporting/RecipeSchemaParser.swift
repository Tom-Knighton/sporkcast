import Foundation

enum RecipeSchemaParser {
    static func parse(scripts: [String], sourceURL: URL) -> ImportedRecipeRecord? {
        for script in scripts.prefix(40) {
            guard let data = script.data(using: .utf8), data.count <= 1_000_000,
                  let root = try? JSONSerialization.jsonObject(with: data) else { continue }
            for node in recipeNodes(root, depth: 0) {
                if let record = makeRecord(node, sourceURL: sourceURL) { return record }
            }
        }
        return nil
    }

    private static func recipeNodes(_ value: Any, depth: Int) -> [[String: Any]] {
        guard depth < 20 else { return [] }
        if let array = value as? [Any] { return array.flatMap { recipeNodes($0, depth: depth + 1) } }
        guard let node = value as? [String: Any] else { return [] }
        let types = (node["@type"] as? [String]) ?? [node["@type"] as? String ?? ""]
        if types.contains(where: { $0 == "Recipe" || $0 == "https://schema.org/Recipe" || $0 == "http://schema.org/Recipe" }) {
            return [node]
        }
        return node.values.flatMap { recipeNodes($0, depth: depth + 1) }
    }

    private static func makeRecord(_ node: [String: Any], sourceURL: URL) -> ImportedRecipeRecord? {
        guard let title = RecipeImportJSONSupport.stringValue(for: ["name"], in: node), !clean(title).isEmpty,
              let rawIngredients = node["recipeIngredient"], let rawSteps = node["recipeInstructions"] else { return nil }
        let ingredients = RecipeImportJSONSupport.normalizeLineList(rawIngredients).map(clean).filter { !$0.isEmpty }
        let sections = stepSections(rawSteps)
        guard !ingredients.isEmpty, !sections.isEmpty else { return nil }
        let ratings = node["aggregateRating"] as? [String: Any] ?? [:]
        let prep = RecipeImportJSONSupport.numericValue(for: ["prepTime"], in: node)
        let cook = RecipeImportJSONSupport.numericValue(for: ["cookTime"], in: node)
        return ImportedRecipeRecord(
            title: clean(title),
            description: RecipeImportJSONSupport.stringValue(for: ["description"], in: node).map(clean),
            author: RecipeImportJSONSupport.stringValue(for: ["author"], in: node).map(clean),
            sourceURL: sourceURL.absoluteString,
            imageURL: imageURL(in: node, sourceURL: sourceURL),
            serves: RecipeImportJSONSupport.stringValue(for: ["recipeYield"], in: node),
            prepMinutes: prep, cookMinutes: cook,
            totalMinutes: RecipeImportJSONSupport.numericValue(for: ["totalTime"], in: node)
                ?? (prep == nil && cook == nil ? nil : (prep ?? 0) + (cook ?? 0)),
            overallRating: RecipeImportJSONSupport.numericValue(for: ["ratingValue"], in: ratings),
            totalRatings: RecipeImportJSONSupport.intValue(for: ["ratingCount", "reviewCount"], in: ratings),
            summarisedRating: nil,
            ratings: reviews(node["review"]),
            ingredientSections: [ImportedIngredientSection(title: "Ingredients", ingredients: ingredients)],
            stepSections: sections
        )
    }

    private static func stepSections(_ value: Any) -> [ImportedStepSection] {
        let values = value as? [Any] ?? [value]
        var sections: [ImportedStepSection] = []
        var pending: [String] = []
        for value in values {
            if let node = value as? [String: Any], let nested = node["itemListElement"] {
                if !pending.isEmpty {
                    sections.append(ImportedStepSection(title: "Method", steps: pending))
                    pending = []
                }
                let lines = RecipeImportJSONSupport.normalizeLineList(nested).map(clean).filter { !$0.isEmpty }
                if !lines.isEmpty {
                    sections.append(ImportedStepSection(
                        title: RecipeImportJSONSupport.stringValue(for: ["name"], in: node).map(clean) ?? "Method", steps: lines))
                }
            } else {
                // HowToStep.name can be only a label; prefer its full text.
                let text: Any = (value as? [String: Any])?["text"] ?? value
                pending += RecipeImportJSONSupport.normalizeLineList(text).map(clean).filter { !$0.isEmpty }
            }
        }
        if !pending.isEmpty { sections.append(ImportedStepSection(title: "Method", steps: pending)) }
        return sections
    }

    private static func reviews(_ value: Any?) -> [ImportedRecipeRating] {
        let nodes = value as? [[String: Any]] ?? (value as? [String: Any]).map { [$0] } ?? []
        return nodes.compactMap { node in
            let rating = RecipeImportJSONSupport.intValue(for: ["ratingValue"], in: node["reviewRating"] as? [String: Any] ?? [:])
            let comment = RecipeImportJSONSupport.stringValue(for: ["reviewBody", "description"], in: node).map(clean)
            guard rating != nil || comment?.isEmpty == false else { return nil }
            return ImportedRecipeRating(id: nil, rating: rating, comment: comment)
        }
    }

    private static func imageURL(in node: [String: Any], sourceURL: URL) -> String? {
        guard let value = RecipeImportJSONSupport.stringValue(for: ["image"], in: node),
              let url = URL(string: value, relativeTo: sourceURL)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url.absoluteString
    }

    private static func clean(_ value: String) -> String {
        SocialRecipePageExtractor.decodeHTMLEntities(
            value.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
