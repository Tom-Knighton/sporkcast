//
//  OpenRecipeIntent.swift
//  sporkcast
//
//  Created by Tom Knighton on 05/07/2026.
//

import AppIntents
import Environment
import Foundation

@available(anyAppleOS 27.0, *)
@AppIntent(schema: .system.open)
public struct OpenRecipeIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Recipe"
    public static let description = IntentDescription("Opens a recipe in Sporkcast.")
    public static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(
        title: "Recipe",
        requestValueDialog: "Which recipe should I open?",
        requestDisambiguationDialog: "Which recipe did you mean?",
        query: RecipeEntryEntityQuery()
    )
    public var target: RecipeEntity

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    public init() {}

    public init(target: RecipeEntity) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        RecipeNavigationHandoff.shared.open(recipeId: target.id)
        return .result(dialog: "Opening \(target.title).")
    }
}
