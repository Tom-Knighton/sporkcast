//
//  RecipeManualCascade.swift
//  Persistence
//
//  Created by Codex on 29/05/2026.
//

import Foundation
import SQLiteData

public enum RecipeManualCascade {
    public static func deleteAllRecipeLinkedData(in db: Database) throws {
        try DBRecipeStepLinkedIngredient.delete().execute(db)
        try DBRecipeStepTemperature.delete().execute(db)
        try DBRecipeStepTiming.delete().execute(db)
        try DBRecipeStep.delete().execute(db)
        try DBRecipeStepGroup.delete().execute(db)
        try DBRecipeIngredient.delete().execute(db)
        try DBRecipeIngredientGroup.delete().execute(db)
        try DBRecipeRating.delete().execute(db)
        try DBRecipeImage.delete().execute(db)
        try DBRecipeFolderAssignment.delete().execute(db)
        try DBRecipeTagAssignment.delete().execute(db)
    }

    public static func deleteRecipeLinkedData(for recipeID: UUID, in db: Database) throws {
        try deleteStepLinkedData(for: recipeID, in: db)
        try deleteIngredientLinkedData(for: recipeID, in: db)
        try DBRecipeRating
            .where { $0.recipeId.eq(recipeID) }
            .delete()
            .execute(db)
        try DBRecipeImage
            .find(recipeID)
            .delete()
            .execute(db)
        try DBRecipeFolderAssignment
            .where { $0.recipeId.eq(recipeID) }
            .delete()
            .execute(db)
        try DBRecipeTagAssignment
            .where { $0.recipeId.eq(recipeID) }
            .delete()
            .execute(db)
    }

    public static func deleteIngredientLinkedData(for recipeID: UUID, in db: Database) throws {
        let ingredientGroupIDs = try DBRecipeIngredientGroup
            .where { $0.recipeId.eq(recipeID) }
            .fetchAll(db)
            .map(\.id)

        if !ingredientGroupIDs.isEmpty {
            try DBRecipeIngredient
                .where { ingredientGroupIDs.contains($0.ingredientGroupId) }
                .delete()
                .execute(db)
        }

        try DBRecipeIngredientGroup
            .where { $0.recipeId.eq(recipeID) }
            .delete()
            .execute(db)
    }

    public static func deleteStepLinkedData(for recipeID: UUID, in db: Database) throws {
        let stepGroupIDs = try DBRecipeStepGroup
            .where { $0.recipeId.eq(recipeID) }
            .fetchAll(db)
            .map(\.id)

        guard !stepGroupIDs.isEmpty else { return }

        let stepIDs = try DBRecipeStep
            .where { stepGroupIDs.contains($0.groupId) }
            .fetchAll(db)
            .map(\.id)

        if !stepIDs.isEmpty {
            try DBRecipeStepLinkedIngredient
                .where { stepIDs.contains($0.recipeStepId) }
                .delete()
                .execute(db)
            try DBRecipeStepTemperature
                .where { stepIDs.contains($0.recipeStepId) }
                .delete()
                .execute(db)
            try DBRecipeStepTiming
                .where { stepIDs.contains($0.recipeStepId) }
                .delete()
                .execute(db)
        }

        try DBRecipeStep
            .where { stepGroupIDs.contains($0.groupId) }
            .delete()
            .execute(db)
        try DBRecipeStepGroup
            .where { $0.recipeId.eq(recipeID) }
            .delete()
            .execute(db)
    }
}
