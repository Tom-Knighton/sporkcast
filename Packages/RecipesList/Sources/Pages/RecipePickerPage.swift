//
//  RecipePickerPage.swift
//  RecipesList
//
//  Created by Tom Knighton on 20/11/2025.
//

import SwiftUI
import Models
import Environment

public struct RecipePickerPage: View {

    private let onRecipeSelected: (UUID) async -> Void

    @State private var repository = RecipesRepository()
    @State private var searchText: String = ""

    private var searchTokens: [String] {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private var filteredRecipes: [Recipe] {
        let tokens = searchTokens
        return repository.recipes
            .filter { recipe in
                matchesSearchText(recipe, searchTokens: tokens) && matchesFurtherFilters(recipe)
            }
    }

    public init(_ onRecipeSelected: @escaping (UUID) async -> Void) {
        self.onRecipeSelected = onRecipeSelected
    }

    public var body: some View {
        List(filteredRecipes) { recipe in
            Button(action: { Task { await self.onRecipeSelected(recipe.id) } }) {
                RecipeCardView(recipe: recipe, enablePreview: false)
                    .contentShape(.rect(cornerRadius: 20))
                    .containerShape(.rect(cornerRadius: 20))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .navigationTitle("Select A Recipe")
        .searchable(text: $searchText, placement: .automatic, prompt: Text("Search recipes, ingredients..."))
    }

    private func matchesSearchText(_ recipe: Recipe, searchTokens: [String]) -> Bool {
        guard !searchTokens.isEmpty else { return true }
        let searchableText = recipe.searchableText
        return searchTokens.allSatisfy { searchableText.contains($0) }
    }

    private func matchesFurtherFilters(_ recipe: Recipe) -> Bool {
        _ = recipe
        return true
    }
}

private extension Recipe {
    var searchableText: String {
        let ingredientText = ingredientSections
            .flatMap { section in
                [section.title] + section.ingredients.flatMap { ingredient in
                    [
                        ingredient.ingredientText,
                        ingredient.ingredientPart,
                        ingredient.extraInformation,
                        ingredient.quantity?.quantityText,
                        ingredient.unit?.unitText,
                    ].compactMap { $0 }
                }
            }
            .joined(separator: " ")

        let stepText = stepSections
            .flatMap { section in
                [section.title] + section.steps.map(\.instructionText)
            }
            .joined(separator: " ")

        let ratingText = ratingInfo?.ratings
            .compactMap(\.comment)
            .joined(separator: " ")

        return [
            title,
            description,
            author,
            summarisedTip,
            serves,
            ingredientText,
            stepText,
            ratingInfo?.summarisedRating,
            ratingText,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .localizedLowercase
    }
}
