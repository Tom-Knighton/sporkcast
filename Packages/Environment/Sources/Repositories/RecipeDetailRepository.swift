//
//  RecipeDetailRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Observation
import Persistence
import Foundation
import Models

@Observable
@MainActor
public final class RecipeDetailRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private var recipeObservation: AnyDatabaseCancellable?

    private var dbRecipe: FullDBRecipe?

    public var recipe: Recipe? {
        dbRecipe?.toDomainModel()
    }

    public init(recipeId: UUID) {
        recipeObservation = observeOne(database, query: DBRecipe.full.find(recipeId)) { error in
            RecipeDebugDiagnostics.logAppEvent("recipe detail observation failed recipeId=\(recipeId) error=\(error)")
        } onChange: { [weak self] recipe in
            self?.dbRecipe = recipe
        }
    }

    public func updateDominantColor(recipeId: UUID, hex: String) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateDominantColor recipeId=\(recipeId)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.dominantColorHex = hex }.execute(db)
        }
        await syncSupabaseSnapshots(forRecipeIds: [recipeId])
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
        await syncSupabaseIngredientUpdates(Array(entries.keys))
    }
    
    public func updateSummarisedTip(to tip: String?, for recipeId: Recipe.ID) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateSummarisedTip recipeId=\(recipeId) hasTip=\(tip != nil)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.summarisedSuggestion = tip }.execute(db)
        }
        await syncSupabaseSnapshots(forRecipeIds: [recipeId])
    }

    public func updateIngredientScale(recipeId: UUID, scale: Double) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateIngredientScale recipeId=\(recipeId) scale=\(scale)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.ingredientScale = scale }.execute(db)
        }
        await syncSupabaseSnapshots(forRecipeIds: [recipeId])
    }

    public func updateIngredientUnitSystem(recipeId: UUID, unitSystem: RecipeIngredientUnitSystem) async throws {
        RecipeDebugDiagnostics.logAppEvent("updateIngredientUnitSystem recipeId=\(recipeId) unitSystem=\(unitSystem.rawValue)")
        try await database.write { db in
            try DBRecipe.find(recipeId).update { $0.ingredientUnitSystem = unitSystem.rawValue }.execute(db)
        }
        await syncSupabaseSnapshots(forRecipeIds: [recipeId])
    }

    private func syncSupabaseSnapshots(forRecipeIds recipeIds: [UUID]) async {

        await enqueueRecipeUpserts(recipeIds)
    }

    private func syncSupabaseSnapshots(forIngredientIds ingredientIds: [UUID]) async {

        do {
            let recipeIds = try await database.read { db in
                var recipeIds: [UUID] = []
                for ingredientId in ingredientIds {
                    guard
                        let ingredient = try DBRecipeIngredient.find(ingredientId).fetchOne(db),
                        let group = try DBRecipeIngredientGroup.find(ingredient.ingredientGroupId).fetchOne(db)
                    else { continue }

                    recipeIds.append(group.recipeId)
                }
                return Array(Set(recipeIds))
            }
            await enqueueRecipeUpserts(recipeIds)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase ingredient detail sync scope lookup failed error=\(error)")
        }
    }

    private func enqueueRecipeUpserts(_ recipeIds: [UUID]) async {
        guard !recipeIds.isEmpty else { return }

        let recipes = (try? await database.read { db in
            try recipeIds.compactMap { recipeId -> (UUID, UUID?)? in
                guard let recipe = try DBRecipe.find(recipeId).fetchOne(db) else { return nil }
                return (recipe.id, recipe.homeId)
            }
        }) ?? []

        for recipe in recipes {
            await SupabaseSyncService.shared.enqueueRecipeUpsert(recipeId: recipe.0, homeId: recipe.1)
        }
        await SupabaseSyncService.shared.drainOutbox(limit: max(20, recipes.count))
    }

    private func syncSupabaseIngredientUpdates(_ ingredientIds: [UUID]) async {

        do {
            try await SupabaseSyncService.shared.pushRecipeIngredients(ingredientIds)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase ingredient emoji direct push failed error=\(error)")
            await syncSupabaseSnapshots(forIngredientIds: ingredientIds)
        }
    }
}
