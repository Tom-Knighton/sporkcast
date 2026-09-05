//
//  RecipeImportIntents.swift
//  sporkcast
//

import API
import AppIntents
import Environment
import Foundation
import Models
import RecipeImporting

@available(anyAppleOS 27.0, *)
public struct ImportRecipeFromWebsiteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Import Recipe from Website"
    public static let description = IntentDescription("Imports a recipe from a website into Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Website", requestValueDialog: "Which website should I import?")
    public var url: URL

    public static var parameterSummary: some ParameterSummary {
        Summary("Import recipe from \(\.$url)")
    }

    public init() {}

    public init(url: URL) {
        self.url = url
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<RecipeEntity> & ProvidesDialog {
        let importedRecipe = try await RecipeIntentImporter.importRecipe(from: url)
        let entity = RecipeEntity(recipe: importedRecipe)
        return .result(value: entity, dialog: "Imported \(importedRecipe.title).")
    }
}

@available(anyAppleOS 27.0, *)
public struct ImportRecipeFromWebsiteAndAddToMealplanIntent: AppIntent {
    public static let title: LocalizedStringResource = "Import Website Recipe and Add to Mealplan"
    public static let description = IntentDescription("Imports a recipe from a website, then adds it to the Sporkcast mealplan.")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Website", requestValueDialog: "Which website should I import?")
    public var url: URL

    @Parameter(title: "Date", requestValueDialog: "Which day should I plan it for?")
    public var date: Date

    @MainActor private var mealplanRepository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Import recipe from \(\.$url) and add it to mealplan on \(\.$date)")
    }

    public init() {
        self.date = .now
    }

    public init(url: URL, date: Date = .now) {
        self.url = url
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<RecipeEntity> & ProvidesDialog {
        let recipe = try await RecipeIntentImporter.importRecipe(from: url)
        let plannedDate = AddRecipeToMealplanIntent.startOfDay(for: date)
        let nextIndex = try await AddRecipeToMealplanIntent.nextMealplanIndex(on: plannedDate, repository: mealplanRepository)

        try await mealplanRepository.addRecipeEntry(
            date: plannedDate,
            index: nextIndex,
            recipeId: recipe.id,
            homeId: HouseholdService.shared.home?.id
        )

        let entity = RecipeEntity(recipe: recipe)
        let formattedDate = plannedDate.formatted(date: .abbreviated, time: .omitted)
        return .result(value: entity, dialog: "Imported \(recipe.title) and added it to the mealplan for \(formattedDate).")
    }
}

@available(anyAppleOS 27.0, *)
@MainActor
private enum RecipeIntentImporter {
    static func importRecipe(from url: URL) async throws -> Recipe {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw RecipeImportError.unreadableFile
        }

        let homeId = HouseholdService.shared.home?.id
        let repository = RecipesRepository(observesChanges: false)
        let coordinator = RecipeImportCoordinator(client: APIClient(host: "https://api.dev.sporkast.tomk.online/"))
        let result = try await coordinator.prepareImport(from: .webURL(url), homeId: homeId)

        guard let candidate = result.candidates.first else {
            throw RecipeImportError.noRecipesDetected
        }

        let existingRecipes = await repository.recipesForDuplicateMatching()
        let duplicates = coordinator.detectDuplicates(for: [candidate], existing: existingRecipes)

        if let duplicate = duplicates[candidate.id],
           let existingRecipe = try await repository.getById([duplicate.existingRecipeID]).first {
            return existingRecipe
        }

        try await repository.saveImportedRecipe(candidate.recipe)
        return candidate.recipe
    }
}
