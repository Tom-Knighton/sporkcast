//
//  RecipeDebugDiagnostics.swift
//  Environment
//
//  Created by Codex on 29/05/2026.
//

import Foundation
import Persistence
import SQLiteData

public enum RecipeDebugDiagnostics {
    public static func logAppEvent(_ message: String) {
        RecipeDebugLogStore.shared.log("APP \(message)")
    }

    public static func logSQLIfRecipeMutation(_ description: String) {
        guard isRecipeMutationSQL(description) else { return }
        RecipeDebugLogStore.shared.logSync("SQL \(description)")
    }

    public static func logRecipeCounts(
        _ label: String,
        database: any DatabaseReader
    ) async {
        do {
            let snapshot = try await database.read { db in
                try RecipeDebugCountSnapshot(db: db)
            }
            RecipeDebugLogStore.shared.log("COUNTS \(label) \(snapshot.summary)")
        } catch {
            RecipeDebugLogStore.shared.log("COUNTS \(label) failed error=\(error)")
        }
    }

    private static func isRecipeMutationSQL(_ description: String) -> Bool {
        let lowercased = description.lowercased()
        guard lowercased.contains("delete") || lowercased.contains("insert") || lowercased.contains("update") else {
            return false
        }

        return [
            "recipes",
            "recipeimages",
            "recipeingredientgroups",
            "recipeingredients",
            "recipestepgroups",
            "recipesteps",
            "recipesteptimings",
            "recipesteptemperatures",
            "recipesteplinkedingredients",
            "reciperatings"
        ].contains { lowercased.contains($0) }
    }
}

private struct RecipeDebugCountSnapshot {
    let recipes: Int
    let images: Int
    let ingredientGroups: Int
    let ingredients: Int
    let stepGroups: Int
    let steps: Int
    let stepTimings: Int
    let stepTemperatures: Int
    let linkedIngredients: Int
    let ratings: Int
    let unsyncedRecordIDs: Int?

    init(db: Database) throws {
        recipes = try DBRecipe.fetchCount(db)
        images = try DBRecipeImage.fetchCount(db)
        ingredientGroups = try DBRecipeIngredientGroup.fetchCount(db)
        ingredients = try DBRecipeIngredient.fetchCount(db)
        stepGroups = try DBRecipeStepGroup.fetchCount(db)
        steps = try DBRecipeStep.fetchCount(db)
        stepTimings = try DBRecipeStepTiming.fetchCount(db)
        stepTemperatures = try DBRecipeStepTemperature.fetchCount(db)
        linkedIngredients = try DBRecipeStepLinkedIngredient.fetchCount(db)
        ratings = try DBRecipeRating.fetchCount(db)
        unsyncedRecordIDs = try? DebugUnsyncedRecordID.fetchCount(db)
    }

    var summary: String {
        [
            "recipes=\(recipes)",
            "images=\(images)",
            "ingredientGroups=\(ingredientGroups)",
            "ingredients=\(ingredients)",
            "stepGroups=\(stepGroups)",
            "steps=\(steps)",
            "stepTimings=\(stepTimings)",
            "stepTemperatures=\(stepTemperatures)",
            "linkedIngredients=\(linkedIngredients)",
            "ratings=\(ratings)",
            "unsyncedRecordIDs=\(unsyncedRecordIDs.map(String.init) ?? "unknown")"
        ].joined(separator: " ")
    }
}

@Table("sqlitedata_icloud_unsyncedRecordIDs")
private struct DebugUnsyncedRecordID: Codable, Sendable {
    let recordName: String
    let zoneName: String
    let ownerName: String
}
