//
//  RecipeStepMapTests.swift
//  Design
//
//  Created by Tom Knighton on 21/09/2025.
//

import Testing
import API
import Models
import Foundation
@testable import Environment

@Test func test() async throws {
    
    // Arrange
    let step = "Start by adding the onion & carrots into a deep non-stick frying pan along with the coconut oil. Gently fry on a medium/ low heat for around 5 minutes. Season with salt."
    
    let ingredients = RecipeDTOMockBuilder().build().ingredients.compactMap { RecipeIngredient(id: UUID(), sortIndex: 0, ingredientText: $0.fullIngredient, ingredientPart: $0.ingredient, extraInformation: $0.extra, quantity: .init(quantity: $0.quantity, quantityText: $0.quantityText), unit: .init(unit: $0.unit, unitText: $0.unitText), emoji: nil, owned: false)}
    
    // Act
    let matchedIngredients = IngredientStepMatcher().matchIngredients(for: step, ingredients: ingredients)
    
    // Assert
    #expect(matchedIngredients.count == 3)
    #expect(matchedIngredients[0].ingredientText == "2  onions, diced ((£0.65/3)=(£0.22))")
    #expect(matchedIngredients[1].ingredientText == "1  carrot, thinly sliced ((£0.09))")
    #expect(matchedIngredients[2].ingredientText == "1 tbsp coconut oil")
}

@Test func testWithRepeatedIngredients_InOrder() async throws {
    
    // Arrange
    let step = "After this time, add the minced garlic, curry powder, ginger, turmeric, honey, soy sauce and flour with a splash of the chicken stock. Gently fry for another minute before gradually adding all of the chicken stock. Reduce to a simmer and set the timer for 20 minutes."
    
    let ingredients = RecipeDTOMockBuilder().build().ingredients.compactMap { RecipeIngredient(id: UUID(), sortIndex: 0, ingredientText: $0.fullIngredient, ingredientPart: $0.ingredient, extraInformation: $0.extra, quantity: .init(quantity: $0.quantity, quantityText: $0.quantityText), unit: .init(unit: $0.unit, unitText: $0.unitText), emoji: nil, owned: false)}
    
    // Act
    let matchedIngredients = IngredientStepMatcher().matchIngredients(for: step, ingredients: ingredients)
    
    // Assert
    #expect(matchedIngredients.count == 8)
    #expect(matchedIngredients[0].ingredientText == "3 cloves of garlic, minced ((£0.69/3)=(£0.23))")
    #expect(matchedIngredients[0].ingredientText == "3 cloves of garlic, minced ((£0.69/3)=(£0.23))")
    #expect(matchedIngredients[1].ingredientText == "1.5 tbsp curry powder")
    #expect(matchedIngredients[2].ingredientText == "1 tbsp ginger, peeled & grated ((£0.55))")
    #expect(matchedIngredients[3].ingredientText == "½ tsp turmeric")
    #expect(matchedIngredients[4].ingredientText == "1 tbsp honey/brown sugar")
    #expect(matchedIngredients[5].ingredientText == "1.5 tbsp soy sauce")
    #expect(matchedIngredients[6].ingredientText == "2 tbsp flour")
    #expect(matchedIngredients[7].ingredientText == "600 ml chicken stock")
}
