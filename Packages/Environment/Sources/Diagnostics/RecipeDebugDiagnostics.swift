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
        if let metadataSummary = recipeMetadataSummary(from: description) {
            RecipeDebugLogStore.shared.logSync("SQL_METADATA \(metadataSummary)")
            return
        }

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
        guard !lowercased.contains("\"sqlitedata_icloud_metadata\"") else {
            return false
        }
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

    private static func recipeMetadataSummary(from description: String) -> String? {
        let lowercased = description.lowercased()
        guard lowercased.contains("\"sqlitedata_icloud_metadata\"") else { return nil }
        guard let tableName = recipeRecordType(in: description) else { return nil }

        let operation: String
        if lowercased.contains("update \"sqlitedata_icloud_metadata\"") {
            operation = "update"
        } else if lowercased.contains("insert into \"sqlitedata_icloud_metadata\"") {
            operation = "insert"
        } else if lowercased.contains("delete from \"sqlitedata_icloud_metadata\"") {
            operation = "delete"
        } else {
            return nil
        }

        return "\(operation) recordType=\(tableName) recordKey=\(recordKey(in: description) ?? "unknown")"
    }

    private static func recipeRecordType(in description: String) -> String? {
        for tableName in recipeTableNames {
            if description.contains(":\(tableName)") || description.contains("'\(tableName)'") {
                return tableName
            }
        }
        return nil
    }

    private static func recordKey(in description: String) -> String? {
        guard let range = description.range(of: "'[0-9a-fA-F-]{36}:[A-Za-z]+'", options: .regularExpression) else {
            return nil
        }
        let value = String(description[range]).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
        return value
    }

    private static let recipeTableNames = [
        "Recipes",
        "RecipeImages",
        "RecipeIngredientGroups",
        "RecipeIngredients",
        "RecipeStepGroups",
        "RecipeSteps",
        "RecipeStepTimings",
        "RecipeStepTemperatures",
        "RecipeStepLinkedIngredients",
        "RecipeRatings"
    ]
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
    let recipesMissingIngredientGroups: Int
    let recipesMissingStepGroups: Int
    let ingredientGroupsWithoutIngredients: Int
    let stepGroupsWithoutSteps: Int

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
        recipesMissingIngredientGroups = try Int.fetchOne(db, sql: """
            SELECT COUNT(*)
            FROM Recipes
            WHERE NOT EXISTS (
                SELECT 1
                FROM RecipeIngredientGroups
                WHERE RecipeIngredientGroups.recipeId = Recipes.id
            )
            """) ?? 0
        recipesMissingStepGroups = try Int.fetchOne(db, sql: """
            SELECT COUNT(*)
            FROM Recipes
            WHERE NOT EXISTS (
                SELECT 1
                FROM RecipeStepGroups
                WHERE RecipeStepGroups.recipeId = Recipes.id
            )
            """) ?? 0
        ingredientGroupsWithoutIngredients = try Int.fetchOne(db, sql: """
            SELECT COUNT(*)
            FROM RecipeIngredientGroups
            WHERE NOT EXISTS (
                SELECT 1
                FROM RecipeIngredients
                WHERE RecipeIngredients.ingredientGroupId = RecipeIngredientGroups.id
            )
            """) ?? 0
        stepGroupsWithoutSteps = try Int.fetchOne(db, sql: """
            SELECT COUNT(*)
            FROM RecipeStepGroups
            WHERE NOT EXISTS (
                SELECT 1
                FROM RecipeSteps
                WHERE RecipeSteps.groupId = RecipeStepGroups.id
            )
            """) ?? 0
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
            "unsyncedRecordIDs=\(unsyncedRecordIDs.map(String.init) ?? "unknown")",
            "recipesMissingIngredientGroups=\(recipesMissingIngredientGroups)",
            "recipesMissingStepGroups=\(recipesMissingStepGroups)",
            "ingredientGroupsWithoutIngredients=\(ingredientGroupsWithoutIngredients)",
            "stepGroupsWithoutSteps=\(stepGroupsWithoutSteps)"
        ].joined(separator: " ")
    }
}

@Table("sqlitedata_icloud_unsyncedRecordIDs")
private struct DebugUnsyncedRecordID: Codable, Sendable {
    let recordName: String
    let zoneName: String
    let ownerName: String
}
