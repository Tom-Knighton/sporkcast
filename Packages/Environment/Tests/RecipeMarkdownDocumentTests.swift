import Foundation
import Persistence
import Testing
@testable import Environment

@Test func recipeMarkdownDocumentRendersRecipeMDSectionsInOrder() throws {
    let recipeID = UUID()
    let ingredientGroupA = UUID()
    let ingredientGroupB = UUID()
    let stepGroupA = UUID()
    let stepGroupB = UUID()

    let recipe = DBRecipe(
        id: recipeID,
        title: "Lemon Garlic Pasta",
        description: "Quick weeknight dinner.",
        author: "Spork Tester",
        sourceUrl: "https://example.com/pasta",
        dominantColorHex: nil,
        minutesToPrepare: 10,
        minutesToCook: 15,
        totalMins: 25,
        serves: "2",
        overallRating: nil,
        totalRatings: 0,
        summarisedRating: nil,
        summarisedSuggestion: nil,
        dateAdded: .now,
        dateModified: .now,
        homeId: nil
    )

    let markdown = RecipeMarkdownDocument(
        recipe: recipe,
        ingredientGroups: [
            .init(id: ingredientGroupB, recipeId: recipeID, title: "Sauce", sortIndex: 1),
            .init(id: ingredientGroupA, recipeId: recipeID, title: "Base", sortIndex: 0)
        ],
        ingredients: [
            .init(id: UUID(), ingredientGroupId: ingredientGroupB, sortIndex: 1, rawIngredient: "2 cloves garlic", quantity: nil, quantityText: nil, unit: nil, unitText: nil, ingredient: nil, extra: nil, emojiDescriptor: nil, owned: false),
            .init(id: UUID(), ingredientGroupId: ingredientGroupA, sortIndex: 0, rawIngredient: "200g pasta", quantity: nil, quantityText: nil, unit: nil, unitText: nil, ingredient: nil, extra: nil, emojiDescriptor: nil, owned: false),
            .init(id: UUID(), ingredientGroupId: ingredientGroupB, sortIndex: 0, rawIngredient: "1 lemon", quantity: nil, quantityText: nil, unit: nil, unitText: nil, ingredient: nil, extra: nil, emojiDescriptor: nil, owned: false)
        ],
        stepGroups: [
            .init(id: stepGroupB, recipeId: recipeID, title: "Finish", sortIndex: 1),
            .init(id: stepGroupA, recipeId: recipeID, title: "Cook", sortIndex: 0)
        ],
        steps: [
            .init(id: UUID(), groupId: stepGroupB, sortIndex: 0, instruction: "Toss with lemon and garlic."),
            .init(id: UUID(), groupId: stepGroupA, sortIndex: 0, instruction: "Boil the pasta."),
            .init(id: UUID(), groupId: stepGroupA, sortIndex: 1, instruction: "Reserve a little pasta water.")
        ]
    ).content

    #expect(markdown.hasPrefix("# Lemon Garlic Pasta"))
    #expect(markdown.contains("## Ingredients"))
    #expect(markdown.contains("## Method"))
    #expect(markdown.contains("- 200g pasta"))
    #expect(markdown.contains("- 1 lemon"))
    #expect(markdown.contains("- 2 cloves garlic"))
    #expect(markdown.contains("1. Boil the pasta."))
    #expect(markdown.contains("2. Reserve a little pasta water."))
    #expect(markdown.contains("3. Toss with lemon and garlic."))

    let firstIngredientRange = try #require(markdown.range(of: "- 200g pasta"))
    let secondIngredientRange = try #require(markdown.range(of: "- 1 lemon"))
    let thirdIngredientRange = try #require(markdown.range(of: "- 2 cloves garlic"))
    #expect(firstIngredientRange.lowerBound < secondIngredientRange.lowerBound)
    #expect(secondIngredientRange.lowerBound < thirdIngredientRange.lowerBound)
}
