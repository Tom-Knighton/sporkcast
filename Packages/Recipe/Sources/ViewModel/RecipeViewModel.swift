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
    
    public init() {
        recipe = nil
    }
    
    public init(for recipe: Recipe, context: ModelContext) {
        self.recipe = recipe
        self.ingredientIconMap = [:]
        
        if recipe.ingredients?.allSatisfy({ $0.emojiDescriptor != nil }) == false {
            try? generateEmojis(context)
        }
    }
    
    public init(with recipeId: UUID, context: ModelContext) async {
        var descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeId }, sortBy: [.init(\.dateModified)])
        descriptor.fetchLimit = 1
        
        let results = try? context.fetch(descriptor)
        self.recipe = results?.first
        
        if results?.first?.ingredients?.allSatisfy({ $0.emojiDescriptor != nil }) == false {
            try? generateEmojis(context)
        }
    }
    
    public init(for url: String, with client: any NetworkClient) async {
        let recipeDto: RecipeDTO? = try? await client.post(Recipes.uploadFromUrl(url: "https://beatthebudget.com/recipe/chicken-katsu-curry/"))
        
        if let recipeDto {
            self.recipe = await Recipe(from: recipeDto)
        } else {
            self.recipe = nil
        }
    }
    
    public func generateEmojis(_ context: ModelContext) throws {
        guard let recipe else { return }
        
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
        
        let ingredients = recipe.ingredients ?? []
        
        Task { [session, context] in
            for ingredient in ingredients {
                do {
                    let response = try await session.respond(
                        to: Prompt(ingredient.rawIngredient),
                        generating: EmojiResponse.self,
                        includeSchemaInPrompt: false,
                        options: .init(temperature: 0.5)
                    )
                    await MainActor.run {
                        ingredient.emojiDescriptor = response.content.emoji
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

