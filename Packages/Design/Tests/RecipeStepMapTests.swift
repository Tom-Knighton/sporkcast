//
//  RecipeStepMapTests.swift
//  Design
//
//  Created by Tom Knighton on 21/09/2025.
//

import Testing
import API
@testable import Design

@Test func test() async throws {
    
    // Arrange
    let mockDTO = RecipeDTOMockBuilder().build()
    let recipe = await Recipe(from: mockDTO)
    let step = RecipeStep(rawStep: "Start by adding the onion & carrots into a deep non-stick frying pan along with the coconut oil. Gently fry on a medium/ low heat for around 5 minutes. Season with salt.", sortIndex: 0, timings: [], temperatures: [])
    
    // Act
    let matchedIngredients = IngredientStepMatcher().matchIngredients(for: step, ingredients: recipe.ingredients ?? [])
    
    matchedIngredients.forEach { ing in
        print(ing.rawIngredient)
    }
    
    // Assert
    #expect(matchedIngredients.count == 3)
    #expect(matchedIngredients[0].rawIngredient == "2  onions, diced ((£0.65/3)=(£0.22))")
    #expect(matchedIngredients[1].rawIngredient == "1  carrot, thinly sliced ((£0.09))")
    #expect(matchedIngredients[2].rawIngredient == "1 tbsp coconut oil")
}
