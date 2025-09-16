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

@Observable
public class RecipeViewModel: @unchecked Sendable {
    
    public let recipe: Recipe?
    public var ingredientIconMap: [String: EmojiResponse] = [:]
    public let session: LanguageModelSession
    
    public init() {
        do {
            session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
            }
            recipe = nil
        } catch {
            print(error)
        }
        
    }
    
    public init(for url: String, with client: any NetworkClient) async {
        self.recipe = try? await client.post(Recipes.uploadFromUrl(url: "https://beatthebudget.com/recipe/chicken-katsu-curry/"))
        
        
        
        
        do {
            session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
            }
            session.prewarm()
            try self.generateEmojis()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func generateEmojis() throws {
        guard let recipe else { return }
        let generalModel = SystemLanguageModel.default
        
        guard generalModel.isAvailable else { return }
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        #endif
        
        Task.detached(name: "emojiLoad") { [recipe, self] in
            for ingredient in recipe.ingredients {
                do {
                    ingredientIconMap[ingredient.id] = try await session.respond(to: Prompt(ingredient.fullIngredient), generating: EmojiResponse.self, includeSchemaInPrompt: false, options: .init(temperature: 0.5)).content
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
