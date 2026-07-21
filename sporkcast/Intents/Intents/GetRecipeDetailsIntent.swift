//
//  GetRecipeDetailsIntent.swift
//  sporkcast
//
//  Created by Tom Knighton on 05/07/2026.
//

import AppIntents
import Environment
import Foundation
import Models
import SwiftUI

@available(anyAppleOS 27.0, *)
public struct GetRecipeDetailsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Recipe Details"
    public static let description = IntentDescription("Shows a short summary and ingredients for a recipe.")

    @Parameter(
        title: "Recipe",
        requestValueDialog: "Which recipe should I show?",
        requestDisambiguationDialog: "Which recipe did you mean?",
        query: RecipeEntryEntityQuery()
    )
    public var recipe: RecipeEntity

    @MainActor private var repository = RecipesRepository(observesChanges: false)

    public static var parameterSummary: some ParameterSummary {
        Summary("Show details for \(\.$recipe)")
    }

    public init() {}

    public init(recipe: RecipeEntity) {
        self.recipe = recipe
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<RecipeEntity> & ProvidesDialog & ShowsSnippetView {
        guard let fullRecipe = try await repository.getById([recipe.id]).first else {
            return .result(value: recipe, dialog: "I couldn't find that recipe.") {
                RecipeResultsSnippetView(title: "Recipe", recipes: [recipe])
            }
        }

        let entity = RecipeEntity(recipe: fullRecipe)
        return .result(value: entity, dialog: dialog(for: fullRecipe)) {
            RecipeDetailSnippetView(recipe: entity, ingredients: ingredientNames(for: fullRecipe))
        }
    }

    private func dialog(for recipe: Recipe) -> IntentDialog {
        let ingredients = ingredientNames(for: recipe)
        guard !ingredients.isEmpty else {
            return "\(recipe.title). \(recipe.description ?? "No ingredients are listed yet.")"
        }

        let ingredientText = ingredients.prefix(5).joined(separator: ", ")
        if ingredients.count > 5 {
            return "\(recipe.title) uses \(ingredientText), and \(ingredients.count - 5) more ingredients."
        }
        return "\(recipe.title) uses \(ingredientText)."
    }

    private func ingredientNames(for recipe: Recipe) -> [String] {
        recipe.ingredientSections
            .flatMap(\.ingredients)
            .map(\.ingredientText)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
