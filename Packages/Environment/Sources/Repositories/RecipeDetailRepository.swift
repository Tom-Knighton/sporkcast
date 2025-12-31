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
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.dominantColorHex = hex }.execute(db)
        }
    }

    public func updateIngredientEmojis(_ entries: [UUID: String?]) async throws {
        try await database.write { db in
            for entry in entries {
                try DBRecipeIngredient.find(entry.key).update { $0.emojiDescriptor = entry.value }.execute(db)
            }
        }
    }
}
