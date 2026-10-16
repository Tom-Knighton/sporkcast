import Foundation
import Models
import Persistence
import Testing
@testable import Environment

@Test @MainActor func duplicateQueryReturnsOnlyPossibleMatchesAndTheirIngredients() async throws {
    let database = try AppDatabaseFactory.makeAppDatabase(path: ":memory:")
    let exactID = UUID()
    let titleID = UUID()
    let unrelatedID = UUID()
    try await database.write { db in
        for (id, title, source) in [
            (exactID, "Old name", "https://example.com/one"),
            (titleID, "Tomato Soup", "https://example.com/two"),
            (unrelatedID, "Unrelated", "https://example.com/three")
        ] {
            let recipe = DBRecipe(id: id, title: title, description: nil, author: nil, sourceUrl: source,
                dominantColorHex: nil, minutesToPrepare: nil, minutesToCook: nil, totalMins: nil, serves: nil,
                overallRating: nil, totalRatings: 0, summarisedRating: nil, summarisedSuggestion: nil,
                dateAdded: .now, dateModified: .now, homeId: nil)
            let groupID = UUID()
            try DBRecipe.insert { recipe }.execute(db)
            try DBRecipeIngredientGroup.insert { DBRecipeIngredientGroup(id: groupID, recipeId: id, title: "Ingredients", sortIndex: 0) }.execute(db)
            try DBRecipeIngredient.insert { DBRecipeIngredient(id: UUID(), ingredientGroupId: groupID, sortIndex: 0,
                rawIngredient: "2 tomatoes", quantity: 2, quantityText: "2", unit: nil, unitText: nil,
                ingredient: "tomatoes", extra: nil, emojiDescriptor: nil, owned: false) }.execute(db)
        }
    }
    let candidates = [duplicateQueryRecipe(title: "Renamed", source: "https://example.com/one?utm_source=share#recipe"),
                      duplicateQueryRecipe(title: " tomato soup ", source: "https://example.com/new")]
    let summaries = try await withDependencies {
        $0.defaultDatabase = database
    } operation: {
        try await RecipesRepository(observesChanges: false).duplicateSummaries(for: candidates)
    }
    #expect(Set(summaries.map(\.id)) == Set([exactID, titleID]))
    #expect(summaries.first(where: { $0.id == exactID })?.ingredientNames.isEmpty == true)
    #expect(summaries.first(where: { $0.id == titleID })?.ingredientNames == ["tomatoes"])
}

private func duplicateQueryRecipe(title: String, source: String) -> Recipe {
    Recipe(id: UUID(), title: title, description: nil, summarisedTip: nil, author: nil, sourceUrl: source,
        image: .init(imageThumbnailData: nil, imageUrl: nil), timing: .init(totalTime: nil, prepTime: nil, cookTime: nil),
        serves: nil, ratingInfo: nil, dateAdded: .now, dateModified: .now, ingredientSections: [], stepSections: [],
        dominantColorHex: nil, homeId: nil)
}
