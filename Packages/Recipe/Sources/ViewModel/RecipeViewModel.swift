//
//  RecipeViewModel.swift
//  Recipe
//
//  Created by Tom Knighton on 14/09/2025.
//

import Models
import Observation
import FoundationModels
import Foundation
import SwiftUI
import Environment

@Observable
@MainActor
public class RecipeViewModel: @unchecked Sendable {
    
    @ObservationIgnored private var defaultRecipe: Recipe
    @ObservationIgnored private let repository: RecipeDetailRepository
    
    public var scrollOffset: CGFloat = 0
    public var showNavTitle: Bool = false
    public var segment: Int = 3
    public var dominantColour: Color = .clear
    public var ingredientsGenerating: Bool = false
    
    public var recipe: Recipe {
        repository.recipe ?? defaultRecipe
    }
    
    public init(recipe: Recipe) {
        self.defaultRecipe = recipe
        self.repository = RecipeDetailRepository(recipeId: recipe.id)
    }
    
    /// Saves the new dominant colour for the recipe directly to the database and to the current view
    public func setDominantColour(to colour: Color) async {
        dominantColour = colour
        
        if let hex = colour.toHex() {
            let id = recipe.id
            try? await repository.updateDominantColor(recipeId: id, hex: hex)
        }
    }
    
    /// Uses Apple Intelligence to generate emojis for each ingredient, and saves them to the model in one go
    public func generateEmojis() async throws {
        
        let ingredients = recipe.ingredientSections.flatMap(\.ingredients)
        
        let ingredientsWithoutEmoji = ingredients.filter { $0.emoji == nil }
        
        if ingredientsWithoutEmoji.isEmpty {
            return
        }
        
        var ingredientEmojiMap: [UUID: String?] = [:]
        
        let session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
        }
        session.prewarm()
        let generalModel = SystemLanguageModel.default
        
        guard generalModel.isAvailable else { print("No model available"); return; }
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("preview, not generating emojis")
            return
        }
        #endif
        
        self.ingredientsGenerating = true
        
        defer { self.ingredientsGenerating = false }
       
        for ingredient in ingredients {
            do {
                let response = try await session.respond(to: Prompt(ingredient.ingredientText), generating: EmojiResponse.self, includeSchemaInPrompt: false, options: .init(temperature: 0.5))
                
                if let emoji = response.content.emoji {
                    ingredientEmojiMap[ingredient.id] = emoji
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        
        try await repository.updateIngredientEmojis(ingredientEmojiMap)
        
        print("Finished generating")
    }
}
