//
//  MarkdownRecipeParser.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation

struct MarkdownRecipeParser {

    func parse(_ markdown: String) -> [ImportedRecipeRecord] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)

        var title: String?
        var descriptionParts: [String] = []
        var ingredients: [String] = []
        var steps: [String] = []

        enum Section {
            case unknown
            case ingredients
            case steps
        }

        var section: Section = .unknown

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard !line.hasPrefix("```") else { continue }

            if line.hasPrefix("#") {
                let heading = cleanedHeading(line)
                guard !heading.isEmpty else { continue }

                if title == nil {
                    title = heading
                    continue
                }

                if isIngredientHeading(heading) {
                    section = .ingredients
                } else if isStepHeading(heading) {
                    section = .steps
                } else {
                    section = .unknown
                }
                continue
            }

            let cleanedLine = strippedListPrefix(from: line)

            switch section {
            case .ingredients:
                ingredients.append(cleanedLine)
            case .steps:
                steps.append(cleanedLine)
            case .unknown:
                if ingredients.isEmpty && looksLikeIngredient(cleanedLine) {
                    ingredients.append(cleanedLine)
                } else if !ingredients.isEmpty && looksLikeStep(cleanedLine) {
                    steps.append(cleanedLine)
                } else if steps.isEmpty && looksLikeStep(cleanedLine) {
                    steps.append(cleanedLine)
                } else if descriptionParts.count < 3 {
                    descriptionParts.append(cleanedLine)
                }
            }
        }

        if steps.isEmpty {
            steps = inferStepsFromParagraphs(markdown)
        }

        let resolvedTitle = title ?? inferTitle(from: lines) ?? "Imported Recipe"

        let record = ImportedRecipeRecord(
            title: resolvedTitle,
            description: descriptionParts.isEmpty ? nil : descriptionParts.joined(separator: " "),
            author: nil,
            sourceURL: nil,
            imageURL: nil,
            serves: nil,
            prepMinutes: nil,
            cookMinutes: nil,
            totalMinutes: nil,
            ingredientSections: [ImportedIngredientSection(title: "Ingredients", ingredients: ingredients)],
            stepSections: [ImportedStepSection(title: "Method", steps: steps)]
        )

        let ingredientCount = record.ingredientSections.flatMap(\.ingredients).filter { !$0.isEmpty }.count
        let stepCount = record.stepSections.flatMap(\.steps).filter { !$0.isEmpty }.count

        guard ingredientCount > 0 || stepCount > 0 else {
            return []
        }

        return [record]
    }

    private func cleanedHeading(_ line: String) -> String {
        line
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func strippedListPrefix(from line: String) -> String {
        var cleaned = line
        cleaned = cleaned.replacingOccurrences(of: "^-\\s+", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^\\*\\s+", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^\\+\\s+", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^\\d+[.)]\\s+", with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferTitle(from lines: [String]) -> String? {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func isIngredientHeading(_ heading: String) -> Bool {
        let lowered = heading.lowercased()
        return lowered.contains("ingredient") || lowered.contains("shopping list")
    }

    private func isStepHeading(_ heading: String) -> Bool {
        let lowered = heading.lowercased()
        return lowered.contains("method") || lowered.contains("instruction") || lowered.contains("direction") || lowered.contains("steps")
    }

    private func looksLikeIngredient(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.range(of: "^\\d", options: .regularExpression) != nil { return true }
        let units = ["tsp", "tbsp", "cup", "cups", "g", "kg", "ml", "l", "oz", "lb", "clove", "pinch"]
        return units.contains { lowered.contains($0) }
    }

    private func looksLikeStep(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.count > 50 { return true }
        let verbs = ["mix", "stir", "cook", "bake", "fry", "heat", "add", "serve", "whisk"]
        return verbs.contains { lowered.contains($0) }
    }

    private func inferStepsFromParagraphs(_ markdown: String) -> [String] {
        let candidates = markdown
            .components(separatedBy: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }
        return Array(candidates.prefix(12))
    }
}
