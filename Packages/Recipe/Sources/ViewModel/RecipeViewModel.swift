//
//  RecipeViewModel.swift
//  Recipe
//
//  Created by Tom Knighton on 14/09/2025.
//

import API
import Observation
import FoundationModels
import Foundation
import SwiftData

@Observable
@MainActor
public class RecipeViewModel: @unchecked Sendable {
    
    public var recipe: Recipe
    
    public init(recipe: Recipe) {
        self.recipe = recipe
    }
    
    public func generateEmojis(_ context: ModelContext, for recipe: Recipe) throws {
        
        let session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
        }
        session.prewarm()
        let generalModel = SystemLanguageModel.default
        
        guard generalModel.isAvailable else { return }
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        #endif
        
        let ingredients = recipe.ingredientSections.flatMap(\.ingredients)
        
        Task { [session, context] in
            for ingredient in ingredients {
                do {
                    let response = try await session.respond(
                        to: Prompt(ingredient.ingredientText),
                        generating: EmojiResponse.self,
                        includeSchemaInPrompt: false,
                        options: .init(temperature: 0.5)
                    )
                    await MainActor.run {
//                        ingredient.emoji = response.content.emoji
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
            await MainActor.run {
                try? context.save()
            }
        }
    }
}

