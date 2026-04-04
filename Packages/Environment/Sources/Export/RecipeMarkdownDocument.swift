//
//  RecipeMarkdownDocument.swift
//  Environment
//
//  Created by Tom Knighton on 04/04/2026.
//

import Foundation
import Persistence

public struct RecipeMarkdownDocument: Sendable, Equatable {
    public let content: String

    public init(recipe fullRecipe: FullDBRecipe) {
        self.content = Self.render(
            recipe: fullRecipe.recipe,
            ingredientGroups: fullRecipe.ingredientGroups,
            ingredients: fullRecipe.ingredients,
            stepGroups: fullRecipe.stepGroups,
            steps: fullRecipe.steps
        )
    }

    public init(
        recipe: DBRecipe,
        ingredientGroups: [DBRecipeIngredientGroup],
        ingredients: [DBRecipeIngredient],
        stepGroups: [DBRecipeStepGroup],
        steps: [DBRecipeStep]
    ) {
        self.content = Self.render(
            recipe: recipe,
            ingredientGroups: ingredientGroups,
            ingredients: ingredients,
            stepGroups: stepGroups,
            steps: steps
        )
    }
}

private extension RecipeMarkdownDocument {
    static func render(
        recipe: DBRecipe,
        ingredientGroups: [DBRecipeIngredientGroup],
        ingredients: [DBRecipeIngredient],
        stepGroups: [DBRecipeStepGroup],
        steps: [DBRecipeStep]
    ) -> String {
        let title = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title.isEmpty ? "Untitled Recipe" : title

        var lines: [String] = []
        lines.append("# \(resolvedTitle)")

        if let description = recipe.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            lines.append("")
            lines.append(description)
        }

        lines.append("")
        lines.append("## Ingredients")
        for ingredient in orderedIngredients(
            ingredientGroups: ingredientGroups,
            ingredients: ingredients
        ) {
            lines.append("- \(ingredient)")
        }

        lines.append("")
        lines.append("## Method")
        for (index, step) in orderedSteps(
            stepGroups: stepGroups,
            steps: steps
        ).enumerated() {
            lines.append("\(index + 1). \(step)")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    static func orderedIngredients(
        ingredientGroups: [DBRecipeIngredientGroup],
        ingredients: [DBRecipeIngredient]
    ) -> [String] {
        let sortedGroups = ingredientGroups.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let groupIDs = Set(sortedGroups.map(\.id))

        let ingredientsByGroupID = Dictionary(grouping: ingredients, by: \.ingredientGroupId)

        var ordered: [DBRecipeIngredient] = []
        ordered.reserveCapacity(ingredients.count)

        for group in sortedGroups {
            let sorted = (ingredientsByGroupID[group.id] ?? []).sorted(by: ingredientSortOrder)
            ordered.append(contentsOf: sorted)
        }

        let orphaned = ingredients
            .filter { !groupIDs.contains($0.ingredientGroupId) }
            .sorted(by: ingredientSortOrder)
        ordered.append(contentsOf: orphaned)

        return ordered
            .map(\.rawIngredient)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func orderedSteps(
        stepGroups: [DBRecipeStepGroup],
        steps: [DBRecipeStep]
    ) -> [String] {
        let sortedGroups = stepGroups.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let groupIDs = Set(sortedGroups.map(\.id))

        let stepsByGroupID = Dictionary(grouping: steps, by: \.groupId)

        var ordered: [DBRecipeStep] = []
        ordered.reserveCapacity(steps.count)

        for group in sortedGroups {
            let sorted = (stepsByGroupID[group.id] ?? []).sorted(by: stepSortOrder)
            ordered.append(contentsOf: sorted)
        }

        let orphaned = steps
            .filter { !groupIDs.contains($0.groupId) }
            .sorted(by: stepSortOrder)
        ordered.append(contentsOf: orphaned)

        return ordered
            .map(\.instruction)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func ingredientSortOrder(lhs: DBRecipeIngredient, rhs: DBRecipeIngredient) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func stepSortOrder(lhs: DBRecipeStep, rhs: DBRecipeStep) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
