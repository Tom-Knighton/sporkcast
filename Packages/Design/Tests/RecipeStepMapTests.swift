//
//  RecipeStepMapTests.swift
//  Design
//
//  Created by Tom Knighton on 21/09/2025.
//

import Testing
import API
import Models
import Environment
import Foundation
@testable import Design

@Test func test() async throws {
    
    // Arrange
    let step = "Start by adding the onion & carrots into a deep non-stick frying pan along with the coconut oil. Gently fry on a medium/ low heat for around 5 minutes. Season with salt."
    let ingredients = RecipeDTOMockBuilder().build().ingredients.compactMap {
        RecipeIngredient(
            id: UUID(),
            sortIndex: 0,
            ingredientText: $0.fullIngredient,
            ingredientPart: $0.ingredient,
            extraInformation: $0.extra,
            quantity: .init(quantity: $0.quantity, quantityText: $0.quantityText),
            unit: .init(unit: $0.unit, unitText: $0.unitText),
            emoji: nil,
            owned: false
        )
    }
    
    // Act
    let matchedIngredients = IngredientStepMatcher().matchIngredients(for: step, ingredients: ingredients)
    
    // Assert
    #expect(matchedIngredients.count == 3)
    #expect(matchedIngredients[0].ingredientText == "2  onions, diced ((£0.65/3)=(£0.22))")
    #expect(matchedIngredients[1].ingredientText == "1  carrot, thinly sliced ((£0.09))")
    #expect(matchedIngredients[2].ingredientText == "1 tbsp coconut oil")
}
