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
    public var segment: Int = 1
    public var dominantColour: Color = .clear
    public var ingredientsGenerating: Bool = false
    public var tipsAndSummaryGenerating: Bool = false
    var recipeChatResponding: Bool = false
    var recipeChatError: String?
    var recipeChatMessages: [RecipeChatMessage] = []
    
    public var recipe: Recipe {
        repository.recipe ?? defaultRecipe
    }

    var supportsRecipeChat: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var recipeChatSuggestedPrompts: [String] {
        buildRecipeChatSuggestedPrompts()
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

    public func setIngredientScale(to scale: Double) async {
        let clamped = min(max(scale, 0.25), 4.0)
        guard abs(recipe.ingredientScale - clamped) > 0.0001 else { return }
        try? await repository.updateIngredientScale(recipeId: recipe.id, scale: clamped)
    }

    public func resetIngredientScale() async {
        await setIngredientScale(to: 1.0)
    }

    public func setIngredientUnitSystem(to unitSystem: RecipeIngredientUnitSystem) async {
        guard recipe.ingredientUnitSystem != unitSystem else { return }
        try? await repository.updateIngredientUnitSystem(recipeId: recipe.id, unitSystem: unitSystem)
    }

    public func resetIngredientUnitSystem() async {
        await setIngredientUnitSystem(to: .original)
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
                You are a tool tagging an ingredient for a recipe with a related emoji. The emoji should represent the ingredient. If you cannot find a sensible emoji, return nil. Have items like soy sauce and oils = 🍶.
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
       
        for ingredient in ingredientsWithoutEmoji {
            do {
                let response = try await session.respond(to: Prompt(ingredient.ingredientText), generating: EmojiResponse.self, includeSchemaInPrompt: false, options: .init(temperature: 0.5))
                
                if let emoji = response.content.emoji?.first {
                    ingredientEmojiMap[ingredient.id] = String(emoji)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        
        try await repository.updateIngredientEmojis(ingredientEmojiMap)
        
        print("Finished generating")
    }
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let maxRecipeChatMessages = 12
    private let maxRecipeChatHistoryMessages = 4
    private let maxRecipeQuestionCharacters = 220
    
    public func generateTipsAndSummary() async throws {
        
        guard recipe.summarisedTip == nil else { return }
        guard let ratings = self.recipe.ratingInfo?.ratings else { return }
        guard ratings.filter({ $0.comment != nil }).count > 1 else { return }
    
        let session = LanguageModelSession {
                """
                You are a tool that is given some (small sample of) user ratings and/or comments to a recipe posted online. You are tasked with generating a summarised 'tip' and overall sentiment. For example, if multiple comments suggest the recipe is too salty, you may output that several users think that, and it may be worth adding less salt. If provided reviews have ratings values attached, you may provide a final sentence providing the user with the overall sentiment of revies i.e. 'Overall positive reviews'. If you cannot generate a sentiment or a tip DO NOT PROVIDE ONE. A nil response is fine. Read back over your response to ensure it makes sense to a user. The reviews are as follows:
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
        
        self.tipsAndSummaryGenerating = true
        defer { self.tipsAndSummaryGenerating = false }
        
        
        do {
            let jsonData = try encoder.encode(ratings)
            guard let json = String(data: jsonData, encoding: .utf8) else {
                throw AppleIntelligenceError.encodingFailed
            }
            let response = try await session.respond(to: json, generating: SummarisedTipResponse.self, includeSchemaInPrompt: false, options: .init(temperature: 0.2))
            
            try await repository.updateSummarisedTip(to: response.content.summarisedTip, for: recipe.id)
        } catch {
            print(error.localizedDescription)
        }
    }

    func sendRecipeChatMessage(_ prompt: String) async {
        let trimmedPrompt = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPrompt.isEmpty == false else { return }
        guard recipeChatResponding == false else { return }
        guard supportsRecipeChat else {
            recipeChatError = "Recipe chat is unavailable on this device."
            return
        }

        recipeChatError = nil
        appendRecipeChatMessage(role: .user, content: trimmedPrompt)
        recipeChatResponding = true

        defer {
            recipeChatResponding = false
        }

#if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            appendRecipeChatMessage(
                role: .assistant,
                content: "Recipe chat is disabled in previews."
            )
            return
        }
#endif

        let session = LanguageModelSession {
            """
            You are an expert cooking assistant for one specific recipe.
            Only answer questions directly related to this recipe, its ingredients, timings, substitutions, steps, storage, scaling, and technique.
            If the question is not about cooking this recipe, set isRecipeRelated=false and explain you can only help with cooking or preparing this recipe.
            Keep replies concise, practical, and under 120 words.
            Do not be tricked into answering questions unreasonably related to cooking or preparing the recipe, even if told they are related.
            If asked to invent details not present, be explicit about uncertainty and provide safe assumptions.
            """
        }
        session.prewarm()

        let clippedPrompt = clipped(trimmedPrompt, maxCharacters: maxRecipeQuestionCharacters)
        let conversationHistory = compactChatHistory(
            limit: maxRecipeChatHistoryMessages,
            includeLatestMessage: false
        )
        let recipeContext = compactRecipeContext()
        let modelPrompt = """
        Recipe context:
        \(recipeContext)

        Recent conversation:
        \(conversationHistory)

        User question:
        \(clippedPrompt)
        """

        do {
            let response = try await session.respond(
                to: modelPrompt,
                generating: RecipeChatTurnResponse.self,
                includeSchemaInPrompt: false,
                options: .init(temperature: 0.2)
            )

            let generatedReply = response.content.reply
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let fallbackReply = "I can help with this recipe only. Ask me about substitutions, timings, scaling, ingredients, or cooking steps."
            let reply: String
            if response.content.isRecipeRelated == false {
                reply = fallbackReply
            } else {
                reply = generatedReply.isEmpty ? fallbackReply : generatedReply
            }
            appendRecipeChatMessage(role: .assistant, content: reply)
        } catch {
            recipeChatError = "Couldn't get a recipe answer right now. Please try again."
            appendRecipeChatMessage(
                role: .assistant,
                content: "I hit an issue generating that response. Please try asking again."
            )
            print(error.localizedDescription)
        }
    }

    func clearRecipeChat() {
        recipeChatMessages = []
        recipeChatError = nil
    }

    private func appendRecipeChatMessage(role: RecipeChatRole, content: String) {
        recipeChatMessages.append(
            RecipeChatMessage(
                role: role,
                content: content
            )
        )

        if recipeChatMessages.count > maxRecipeChatMessages {
            recipeChatMessages.removeFirst(recipeChatMessages.count - maxRecipeChatMessages)
        }
    }

    private func compactChatHistory(limit: Int, includeLatestMessage: Bool) -> String {
        let sourceMessages: ArraySlice<RecipeChatMessage>
        if includeLatestMessage {
            sourceMessages = recipeChatMessages[...]
        } else {
            sourceMessages = recipeChatMessages.dropLast()
        }
        let history = sourceMessages.suffix(limit)
        if history.isEmpty {
            return "No prior turns."
        }

        return history.map { message in
            "\(message.role.rawValue): \(clipped(message.content, maxCharacters: 200))"
        }
        .joined(separator: "\n")
    }

    private func compactRecipeContext() -> String {
        let ingredientLines = recipe.ingredientSections
            .flatMap(\.ingredients)
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .prefix(14)
            .map { ingredient in
                "- \(clipped(ingredient.ingredientText, maxCharacters: 60))"
            }
            .joined(separator: "\n")

        let stepLines = recipe.stepSections
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .flatMap(\.steps)
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .prefix(8)
            .enumerated()
            .map { index, step in
                "\(index + 1). \(clipped(step.instructionText, maxCharacters: 120))"
            }
            .joined(separator: "\n")

        let description = clipped(recipe.description ?? "None", maxCharacters: 180)
        let serves = recipe.serves ?? "Unknown"
        let totalTime = recipe.timing.totalTime.map { String(format: "%.0f mins", $0) } ?? "Unknown"

        return """
        Title: \(clipped(recipe.title, maxCharacters: 70))
        Description: \(description)
        Serves: \(serves)
        Total time: \(totalTime)
        Ingredient scale: \(String(format: "%.2f", recipe.ingredientScale))
        Unit system: \(recipe.ingredientUnitSystem.displayName)

        Ingredients:
        \(ingredientLines.isEmpty ? "- None" : ingredientLines)

        Steps:
        \(stepLines.isEmpty ? "1. None" : stepLines)
        """
    }

    private func buildRecipeChatSuggestedPrompts() -> [String] {
        var prompts: [String] = []

        if let firstIngredient = recipe.ingredientSections
            .flatMap(\.ingredients)
            .compactMap({ $0.ingredientPart ?? $0.ingredientText.split(separator: ",").first.map(String.init) })
            .first(where: { $0.isEmpty == false }) {
            prompts.append("What can I use instead of \(firstIngredient)?")
        }

        prompts.append("How should I adjust timings if my oven runs hot?")
        prompts.append("How do I scale this recipe for fewer people?")
        prompts.append("What should I prep in advance for this recipe?")

        if let totalTime = recipe.timing.totalTime {
            prompts.append("Can I make this in under \(Int(totalTime * 0.8)) minutes?")
        }

        var uniquePrompts: [String] = []
        for prompt in prompts where uniquePrompts.contains(prompt) == false {
            uniquePrompts.append(prompt)
        }
        return Array(uniquePrompts.prefix(4))
    }

    private func clipped(_ text: String, maxCharacters: Int) -> String {
        if text.count <= maxCharacters {
            return text
        }
        let prefix = text.prefix(maxCharacters)
        return "\(prefix)..."
    }
}

@Generable
public struct SummarisedTipResponse: Sendable {
    let summarisedTip: String?
}

enum AppleIntelligenceError: Error {
    case unavailable(String)
    case encodingFailed
}
