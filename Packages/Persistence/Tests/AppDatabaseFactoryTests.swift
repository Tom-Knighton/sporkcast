import Testing
@testable import Persistence
import Foundation

@Test func makeAppDatabaseSupportsMigrations() async throws {
    let database = try AppDatabaseFactory.makeAppDatabase(path: temporaryDatabasePath())

    let entry = DBMealplanEntry(
        id: UUID(),
        date: .now,
        index: 0,
        noteText: "Preview entry",
        recipeId: nil, homeId: nil
    )

    try await database.write { db in
        try DBMealplanEntry.insert { entry }.execute(db)
    }

    let fetched = try await database.read { db in
        return try DBMealplanEntry.fetchAll(db)
    }

    #expect(!fetched.isEmpty)
    #expect(fetched.first?.noteText == entry.noteText)
}

@Test func fullRecipeQueryHydratesImportedChildren() async throws {
    let database = try AppDatabaseFactory.makeAppDatabase(path: temporaryDatabasePath())
    let recipeId = UUID()
    let ingredientGroupId = UUID()
    let ingredientId = UUID()
    let stepGroupId = UUID()
    let stepId = UUID()

    let recipe = DBRecipe(
        id: recipeId,
        title: "Imported recipe",
        description: nil,
        author: nil,
        sourceUrl: "https://example.com/recipe",
        dominantColorHex: nil,
        minutesToPrepare: nil,
        minutesToCook: nil,
        totalMins: nil,
        serves: nil,
        overallRating: nil,
        totalRatings: 0,
        summarisedRating: nil,
        summarisedSuggestion: nil,
        dateAdded: .now,
        dateModified: .now,
        homeId: nil
    )
    let image = DBRecipeImage(recipeId: recipeId, imageSourceUrl: "https://example.com/image.jpg", imageData: Data([1, 2, 3]))
    let ingredientGroup = DBRecipeIngredientGroup(id: ingredientGroupId, recipeId: recipeId, title: "Ingredients", sortIndex: 0)
    let ingredient = DBRecipeIngredient(
        id: ingredientId,
        ingredientGroupId: ingredientGroupId,
        sortIndex: 0,
        rawIngredient: "1 onion",
        quantity: 1,
        quantityText: "1",
        unit: nil,
        unitText: nil,
        ingredient: "onion",
        extra: nil,
        emojiDescriptor: nil,
        owned: false
    )
    let stepGroup = DBRecipeStepGroup(id: stepGroupId, recipeId: recipeId, title: "Method", sortIndex: 0)
    let step = DBRecipeStep(id: stepId, groupId: stepGroupId, sortIndex: 0, instruction: "Chop the onion.")

    try await database.write { db in
        try DBRecipe.insert { recipe }.execute(db)
        try DBRecipeImage.insert { image }.execute(db)
        try DBRecipeIngredientGroup.insert { ingredientGroup }.execute(db)
        try DBRecipeIngredient.insert { ingredient }.execute(db)
        try DBRecipeStepGroup.insert { stepGroup }.execute(db)
        try DBRecipeStep.insert { step }.execute(db)
    }

    let fetched = try await database.read { db in
        try DBRecipe.full.find(recipeId).fetchOne(db)
    }

    #expect(fetched?.imageData == image)
    #expect(fetched?.ingredientGroups == [ingredientGroup])
    #expect(fetched?.ingredients == [ingredient])
    #expect(fetched?.stepGroups == [stepGroup])
    #expect(fetched?.steps == [step])
}

private func temporaryDatabasePath() -> String {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(UUID().uuidString).sqlite")
        .path
}
