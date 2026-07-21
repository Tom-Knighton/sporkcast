//
//  FindRecipesIntent.swift
//  sporkcast
//
//  Created by Tom Knighton on 05/07/2026.
//

import AppIntents
internal import AppRouter
import Environment
import Foundation
import SwiftUI

@available(anyAppleOS 27.0, *)
@AssistantIntent(schema: .system.search)
public struct SearchRecipesInAppIntent: ShowInAppSearchResultsIntent {
    public static let title: LocalizedStringResource = "Search Recipes"
    public static let description = IntentDescription("Opens Sporkcast and shows matching recipes.")
    public static let searchScopes: [StringSearchScope] = [.general]

    @Parameter(title: "Search", requestValueDialog: "What recipe should I look for?")
    public var criteria: StringSearchCriteria

    public static var parameterSummary: some ParameterSummary {
        Summary("Find recipes matching \(\.$criteria)")
    }

    public init() {
        self.criteria = StringSearchCriteria(term: "")
    }

    public init(searchTerm: String) {
        self.criteria = StringSearchCriteria(term: searchTerm)
    }

    @MainActor
    private var repository = RecipesRepository(observesChanges: false)

    public func perform() async throws -> some IntentResult & ReturnsValue<[RecipeEntity]> & ProvidesDialog & ShowsSnippetView {
        let trimmedSearchTerm = normalizedRecipeSearch(criteria.term)
        await RecipeSearchHandoff.shared.search(trimmedSearchTerm)
        let recipes = try await repository
            .getIntentSummariesByLookup(trimmedSearchTerm, limit: 8, returnsSuggestionsForEmptyLookup: false)
            .map { RecipeEntity(summary: $0) }

        let dialog: IntentDialog = if trimmedSearchTerm.isEmpty {
            "I couldn't tell what to search for."
        } else {
            recipes.isEmpty ? "No recipes found for \(trimmedSearchTerm)." : "Here are recipes matching \(trimmedSearchTerm)."
        }

        return .result(value: recipes, dialog: dialog) {
            RecipeResultsSnippetView(title: recipeResultsTitle(for: trimmedSearchTerm), recipes: recipes)
        }
    }

    private func recipeResultsTitle(for searchTerm: String) -> String {
        searchTerm.isEmpty ? "Recipes" : "Recipes matching \(searchTerm)"
    }
}

@available(anyAppleOS 27.0, *)
public struct FindRecipeResultsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Find Recipes"
    public static let description = IntentDescription("Finds matching Sporkcast recipes and shows them without opening the app.")
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Search",
        requestValueDialog: "What recipe should I look for?",
        requestDisambiguationDialog: "What should I search for?",
        query: RecipeSearchQueryEntityQuery()
    )
    public var search: RecipeSearchQueryEntity

    public static var parameterSummary: some ParameterSummary {
        Summary("Find recipes matching \(\.$search)")
    }

    public init() {
        self.search = RecipeSearchQueryEntity(query: "")
    }

    public init(searchTerm: String) {
        self.search = RecipeSearchQueryEntity(query: searchTerm)
    }

    @MainActor
    private var repository = RecipesRepository(observesChanges: false)

    public func perform() async throws -> some IntentResult & ReturnsValue<[RecipeEntity]> & ProvidesDialog & ShowsSnippetView {
        let trimmedSearchTerm = normalizedRecipeSearch(search.query)
        let recipes = try await repository
            .getIntentSummariesByLookup(trimmedSearchTerm, limit: 8, returnsSuggestionsForEmptyLookup: false)
            .map { RecipeEntity(summary: $0) }

        let dialog: IntentDialog = if trimmedSearchTerm.isEmpty {
            "I couldn't tell what to search for."
        } else {
            recipes.isEmpty ? "No recipes found for \(trimmedSearchTerm)." : "Here are recipes matching \(trimmedSearchTerm)."
        }

        return .result(value: recipes, dialog: dialog) {
            RecipeResultsSnippetView(
                title: trimmedSearchTerm.isEmpty ? "Recipes" : "Recipes matching \(trimmedSearchTerm)",
                recipes: recipes
            )
        }
    }
}

@available(anyAppleOS 27.0, *)
nonisolated private func normalizedRecipeSearch(_ searchTerm: String) -> String {
    let normalizedSearchTerm = RecipeSearchNormalizer.normalizedQuery(searchTerm)
    return normalizedSearchTerm.isEmpty
        ? searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        : normalizedSearchTerm
}

@available(anyAppleOS 27.0, *)
public struct FindRecipesShortcutIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Recipe Search"
    public static let description = IntentDescription("Opens recipe search in Sporkcast.")
    public static let supportedModes: IntentModes = .foreground(.immediate)

    public static var parameterSummary: some ParameterSummary {
        Summary("Open recipe search")
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        AppRouter.shared.selectedTab = .recipes
        AppRouter.shared[.recipes] = [.recipes()]
        RecipeSearchHandoff.shared.search("")
        return .result(dialog: "Opening recipe search.")
    }
}
