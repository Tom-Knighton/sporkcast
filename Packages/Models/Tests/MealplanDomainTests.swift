import Persistence
import Testing
@testable import Models

@Test func mealplanEntryDomainMappingIncludesRecipe() throws {
    let recipeId = UUID()
    let entryId = UUID()
    let now = Date()

    let full = FullDBMealplanEntry(
        mealplanEntry: DBMealplanEntry(id: entryId, date: now, index: 2, noteText: "Bring dessert", recipeId: recipeId),
        recipe: DBRecipe(
            id: recipeId,
            title: "Curry", description: "", author: "Test", sourceUrl: "https://example.com",
            dominantColorHex: nil,
            minutesToPrepare: 10,
            minutesToCook: 20,
            totalMins: 30,
            serves: "4",
            overallRating: 4.0,
            summarisedRating: nil,
            summarisedSuggestion: nil,
            dateAdded: now,
            dateModified: now,
            homeId: nil
        ),
        image: DBRecipeImage(recipeId: recipeId, imageSourceUrl: nil, imageData: nil)
    )

    let domain = full.toDomainModel()

    #expect(domain.id == entryId)
    #expect(domain.index == 2)
    #expect(domain.recipe?.title == "Curry")
    #expect(domain.recipe?.image.imageThumbnailData == nil)
}
