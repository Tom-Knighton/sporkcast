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
    
    public var recipe: Recipe?
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
    
    public init(for recipe: Recipe) {
        self.recipe = recipe
        self.ingredientIconMap = [:]
        session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
        }
        session.prewarm()
    }
    
    public init(with recipeId: UUID, context: ModelContext) async {
        var descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeId }, sortBy: [.init(\.dateModified)])
        descriptor.fetchLimit = 1
        
        self.session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
        }
        session.prewarm()
        
        let results = try? context.fetch(descriptor)
        self.recipe = results?.first
    }
    
    public init(for url: String, with client: any NetworkClient) async {
        let recipeDto: RecipeDTO? = try? await client.post(Recipes.uploadFromUrl(url: "https://beatthebudget.com/recipe/chicken-katsu-curry/"))
        
        if let recipeDto {
            self.recipe = await Recipe(from: recipeDto)
        } else {
            self.recipe = nil
        }
        self.session = LanguageModelSession {
                """
                You are a tool tagging an ingredient for a recipe with a related emoji. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
                """
        }
        session.prewarm()
        
        do {
            
//            try self.generateEmojis()
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
        
//        Task.detached(name: "emojiLoad") { [recipe, self] in
//            for ingredient in recipe.ingredients {
//                do {
//                    ingredientIconMap[ingredient.id] = try await session.respond(to: Prompt(ingredient.fullIngredient), generating: EmojiResponse.self, includeSchemaInPrompt: false, options: .init(temperature: 0.5)).content
//                } catch {
//                    print(error.localizedDescription)
//                }
//            }
//        }
    }
}
