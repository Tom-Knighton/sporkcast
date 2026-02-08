import Dependencies
import Models
import Persistence
import SwiftUI
import Testing
@testable import Recipe

@MainActor
@Test func setDominantColourPersistsToDatabase() async throws {
    let db = try AppDatabaseFactory.makeAppDatabase()
    let recipeId = UUID()
    let now = Date()

    let recipe = Recipe(
        id: recipeId,
        title: "Test Recipe",
        description: nil,
        summarisedTip: nil,
        author: nil,
        sourceUrl: "https://example.com",
        image: .init(imageThumbnailData: nil, imageUrl: nil),
        timing: .init(totalTime: nil, prepTime: nil, cookTime: nil),
        serves: nil,
        ratingInfo: nil,
        dateAdded: now,
        dateModified: now,
        ingredientSections: [],
        stepSections: [],
        dominantColorHex: nil,
        homeId: nil
    )

    try await db.write { db in
        try DBRecipe.insert {
            DBRecipe(
                id: recipeId,
                title: recipe.title,
                description: recipe.description,
                author: recipe.author,
                sourceUrl: recipe.sourceUrl,
                dominantColorHex: recipe.dominantColorHex,
                minutesToPrepare: recipe.timing.prepTime,
                minutesToCook: recipe.timing.cookTime,
                totalMins: recipe.timing.totalTime,
                serves: recipe.serves,
                overallRating: recipe.ratingInfo?.overallRating,
                totalRatings: recipe.ratingInfo?.totalRatings ?? 0,
                summarisedRating: recipe.ratingInfo?.summarisedRating,
                summarisedSuggestion: nil,
                dateAdded: now,
                dateModified: now,
                homeId: recipe.homeId
            )
        }
        .execute(db)
    }

    let viewModel = withDependencies {
        $0.defaultDatabase = db
    } operation: {
        RecipeViewModel(recipe: recipe)
    }

    let targetColour: Color = .purple
    await viewModel.setDominantColour(to: targetColour)

    #expect(viewModel.dominantColour == targetColour)

    let persisted = try await db.read { db in
        try DBRecipe.find(recipeId).fetchOne(db)
    }

    #expect(persisted?.dominantColorHex == targetColour.toHex())
}
