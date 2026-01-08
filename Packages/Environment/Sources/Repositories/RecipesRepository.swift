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
            try DBMealplanEntry.where { $0.recipeId == id }.delete().execute(db)
        }
    }

    public func saveImportedRecipe(
        _ entities: (DBRecipe, DBRecipeImage, [DBRecipeIngredientGroup], [DBRecipeIngredient], [DBRecipeStepGroup], [DBRecipeStep], [DBRecipeStepTiming], [DBRecipeStepTemperature], [DBRecipeRating])
    ) async throws {
        let (recipe, image, ingredientGroups, ingredients, stepGroups, steps, timings, temperatures, ratings) = entities
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
        }
    }
}
