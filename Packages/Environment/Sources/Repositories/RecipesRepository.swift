//
//  RecipesRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Models
import Observation
import SQLiteData
import Persistence
import Foundation

@Observable
@MainActor
public final class RecipesRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchAll(DBRecipe.full) private var dbRecipes: [FullDBRecipe]

    public var recipes: [Recipe] {
        dbRecipes.compactMap { $0.toDomainModel() }
    }

    public init() {}

    public func deleteAll() async throws {
        try await database.write { db in
            try DBRecipe.delete().execute(db)
        }
    }
    
    public func delete(_ id: Recipe.ID) async throws  {
        print(id)
        try await database.write { db in
            try DBRecipe.find(id).delete().execute(db)
            try DBMealplanEntry.where { $0.recipeId.eq(id) }.delete().execute(db)
        }
    }

    public func saveImportedRecipe(
        _ entities: (DBRecipe, DBRecipeImage, [DBRecipeIngredientGroup], [DBRecipeIngredient], [DBRecipeStepGroup], [DBRecipeStep], [DBRecipeStepTiming], [DBRecipeStepTemperature], [DBRecipeRating], [DBRecipeStepLinkedIngredient])
    ) async throws {
        let (recipe, image, ingredientGroups, ingredients, stepGroups, steps, timings, temperatures, ratings, linkedIngredients) = entities
        try await database.write { db in
            try DBRecipe.insert { recipe }.execute(db)
            try DBRecipeImage.insert { image }.execute(db)
            try DBRecipeIngredientGroup.insert { ingredientGroups }.execute(db)
            try DBRecipeIngredient.insert { ingredients }.execute(db)
            try DBRecipeStepGroup.insert { stepGroups }.execute(db)
            try DBRecipeStep.insert { steps }.execute(db)
            try DBRecipeStepTiming.insert { timings }.execute(db)
            try DBRecipeStepTemperature.insert { temperatures }.execute(db)
            try DBRecipeRating.insert { ratings }.execute(db)
            try DBRecipeStepLinkedIngredient.insert { linkedIngredients }.execute(db)
        }
    }

    public func saveImportedRecipe(_ recipe: Recipe) async throws {
        let entities = await Recipe.entites(from: recipe)
        try await saveImportedRecipe(entities)
    }

    public func replaceImportedRecipe(existingRecipeId: UUID, with importedRecipe: Recipe) async throws {
        let recipe = importedRecipe.copy(id: existingRecipeId)
        let entities = await Recipe.entites(from: recipe)

        let (newRecipe, newImage, newIngGroups, newIngs, newStepGroups, newSteps, newStepTimings, newStepTemps, newRatings, newLinkedIngredients) = entities

        try await database.write { db in
            try DBRecipe
                .upsert { newRecipe }
                .execute(db)

            try DBRecipeImage
                .upsert { newImage }
                .execute(db)

            let existingIngredientGroups = try DBRecipeIngredientGroup
                .where { $0.recipeId.eq(existingRecipeId) }
                .fetchAll(db)
                .map(\.id)

            if !existingIngredientGroups.isEmpty {
                try DBRecipeIngredient
                    .where { existingIngredientGroups.contains($0.ingredientGroupId) }
                    .delete()
                    .execute(db)
            }

            try DBRecipeIngredientGroup
                .where { $0.recipeId.eq(existingRecipeId) }
                .delete()
                .execute(db)

            let existingStepGroups = try DBRecipeStepGroup
                .where { $0.recipeId.eq(existingRecipeId) }
                .fetchAll(db)
                .map(\.id)

            if !existingStepGroups.isEmpty {
                let existingSteps = try DBRecipeStep
                    .where { existingStepGroups.contains($0.groupId) }
                    .fetchAll(db)
                    .map(\.id)

                if !existingSteps.isEmpty {
                    try DBRecipeStepTiming
                        .where { existingSteps.contains($0.recipeStepId) }
                        .delete()
                        .execute(db)
                    try DBRecipeStepTemperature
                        .where { existingSteps.contains($0.recipeStepId) }
                        .delete()
                        .execute(db)
                    try DBRecipeStepLinkedIngredient
                        .where { existingSteps.contains($0.recipeStepId) }
                        .delete()
                        .execute(db)
                }

                try DBRecipeStep
                    .where { existingStepGroups.contains($0.groupId) }
                    .delete()
                    .execute(db)
            }

            try DBRecipeStepGroup
                .where { $0.recipeId.eq(existingRecipeId) }
                .delete()
                .execute(db)

            try DBRecipeRating
                .where { $0.recipeId.eq(existingRecipeId) }
                .delete()
                .execute(db)

            try DBRecipeIngredientGroup
                .insert { newIngGroups }
                .execute(db)

            try DBRecipeIngredient
                .insert { newIngs }
                .execute(db)

            try DBRecipeStepGroup
                .insert { newStepGroups }
                .execute(db)

            try DBRecipeStep
                .insert { newSteps }
                .execute(db)

            try DBRecipeStepTiming
                .insert { newStepTimings }
                .execute(db)

            try DBRecipeStepTemperature
                .insert { newStepTemps }
                .execute(db)

            try DBRecipeStepLinkedIngredient
                .insert { newLinkedIngredients }
                .execute(db)

            try DBRecipeRating
                .insert { newRatings }
                .execute(db)
        }
    }
}

private extension Recipe {
    func copy(id: UUID) -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: description,
            summarisedTip: summarisedTip,
            author: author,
            sourceUrl: sourceUrl,
            image: image,
            timing: timing,
            serves: serves,
            ratingInfo: ratingInfo,
            dateAdded: dateAdded,
            dateModified: .now,
            ingredientSections: ingredientSections,
            stepSections: stepSections,
            dominantColorHex: dominantColorHex,
            homeId: homeId
        )
    }
}
