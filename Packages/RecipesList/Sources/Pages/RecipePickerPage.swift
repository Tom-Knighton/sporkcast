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
    @State private var isFilterSheetPresented = false
    @State private var filters = RecipeFilters()

    private var searchTokens: [String] {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private var filteredRecipes: [Recipe] {
        let tokens = searchTokens
        let filtered = repository.recipes
            .filter { recipe in
                matchesSearchText(recipe, searchTokens: tokens) && matchesFilters(recipe)
            }
        return sortedRecipes(filtered)
    }

    public init(_ onRecipeSelected: @escaping (UUID) async -> Void) {
        self.onRecipeSelected = onRecipeSelected
    }

    public var body: some View {
        List(filteredRecipes) { recipe in
            Button(action: { selectRecipe(recipe.id) }) {
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
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button(action: presentFilters) {
                    Image(systemName: filters.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                }
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: Text("Search recipes, ingredients..."))
        .sheet(isPresented: $isFilterSheetPresented) {
            RecipeFiltersSheet(filters: $filters)
        }
    }

    private func selectRecipe(_ recipeId: UUID) {
        Task {
            await onRecipeSelected(recipeId)
        }
    }

    private func presentFilters() {
        isFilterSheetPresented = true
    }

    private func matchesSearchText(_ recipe: Recipe, searchTokens: [String]) -> Bool {
        guard !searchTokens.isEmpty else { return true }
        let searchableText = recipe.searchableText
        return searchTokens.allSatisfy { searchableText.contains($0) }
    }

    private func matchesFilters(_ recipe: Recipe) -> Bool {
        if filters.minimumRating > 0 {
            guard let rating = recipe.filterRating, rating >= filters.minimumRating else { return false }
        }

        if filters.minimumComments > 0, recipe.filterCommentCount < filters.minimumComments {
            return false
        }

        if filters.maximumTimeMinutes > 0 {
            guard let time = recipe.filterTimeMinutes, time <= Double(filters.maximumTimeMinutes) else { return false }
        }

        return true
    }

    private func sortedRecipes(_ recipes: [Recipe]) -> [Recipe] {
        switch filters.sort {
        case .nameAZ:
            return recipes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .nameZA:
            return recipes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            }
        case .dateAdded:
            return recipes.sorted { $0.dateAdded > $1.dateAdded }
        case .dateModified:
            return recipes.sorted { $0.dateModified > $1.dateModified }
        case .time:
            return recipes.sorted { lhs, rhs in
                switch (lhs.filterTimeMinutes, rhs.filterTimeMinutes) {
                case let (left?, right?):
                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
        }
    }
}

extension Recipe {
    var filterRating: Double? {
        ratingInfo?.overallRating
    }

    var filterCommentCount: Int {
        let parsedCommentCount = ratingInfo?.ratings
            .compactMap(\.comment)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count ?? 0

        if parsedCommentCount > 0 {
            return parsedCommentCount
        }

        return ratingInfo?.totalRatings ?? 0
    }

    var filterTimeMinutes: Double? {
        timing.totalTime ?? timing.cookTime ?? timing.prepTime
    }

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
