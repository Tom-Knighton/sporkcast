//
//  RecipeDetailRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Observation
import SQLiteData
import Persistence
import Foundation
import Models

@Observable
@MainActor
public final class RecipeDetailRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchOne private var dbRecipe: FullDBRecipe?

    public var recipe: Recipe? {
        dbRecipe?.toDomainModel()
    }

    public init(recipeId: UUID) {
        self._dbRecipe = FetchOne(DBRecipe.full.find(recipeId))
    }

    public func updateDominantColor(recipeId: UUID, hex: String) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateDominantColor recipeId=\(recipeId)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.dominantColorHex = #bind(hex) }.execute(db)
        }
    }

    public func updateIngredientEmojis(_ entries: [UUID: String?]) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateIngredientEmojis ingredientCount=\(entries.count) ingredientIds=\(entries.keys.map(\.uuidString).joined(separator: ","))")
        await RecipeDebugDiagnostics.logRecipeCounts("before updateIngredientEmojis ingredientCount=\(entries.count)", database: database)
        try await database.write { db in
            for entry in entries {
                try DBRecipeIngredient.find(entry.key).update { $0.emojiDescriptor = entry.value }.execute(db)
            }
        }
        await RecipeDebugDiagnostics.logRecipeCounts("after updateIngredientEmojis ingredientCount=\(entries.count)", database: database)
    }
    
    public func updateSummarisedTip(to tip: String?, for recipeId: Recipe.ID) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateSummarisedTip recipeId=\(recipeId) hasTip=\(tip != nil)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.summarisedSuggestion = tip }.execute(db)
        }
    }

    public func updateIngredientScale(recipeId: UUID, scale: Double) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateIngredientScale recipeId=\(recipeId) scale=\(scale)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.ingredientScale = scale }.execute(db)
        }
    }

    public func updateIngredientUnitSystem(recipeId: UUID, unitSystem: RecipeIngredientUnitSystem) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateIngredientUnitSystem recipeId=\(recipeId) unitSystem=\(unitSystem.rawValue)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.ingredientUnitSystem = unitSystem.rawValue }.execute(db)
        }
    }
}
