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
    let step = recipe.stepSections!.first!.steps!.first!
    
    // Act
    let matchedIngredients = IngredientStepMatcher().matchIngredients(for: step, ingredients: recipe.ingredients ?? [])
    
    matchedIngredients.forEach { ing in
        print(ing.rawIngredient)
    }
    // Assert
    #expect(matchedIngredients.count == 3)
}
