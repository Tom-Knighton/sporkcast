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

    public typealias ImportedRecipeEntities = (
        DBRecipe,
        DBRecipeImage,
        [DBRecipeIngredientGroup],
        [DBRecipeIngredient],
        [DBRecipeStepGroup],
        [DBRecipeStep],
        [DBRecipeStepTiming],
        [DBRecipeStepTemperature],
        [DBRecipeRating],
        [DBRecipeStepLinkedIngredient]
    )

    private static let importWriteBatchSize = 25
    private static let importImageHydrationFetchConcurrency = 8
    private static let importImageHydrationWriteBatchSize = 24

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

    public func saveImportedRecipe(_ entities: ImportedRecipeEntities) async throws {
        try await saveImportedRecipes([entities])
    }

    public func saveImportedRecipe(_ recipe: Recipe) async throws {
        try await saveImportedRecipes([recipe])
    }

    public func saveImportedRecipes(_ recipes: [Recipe]) async throws {
        guard !recipes.isEmpty else { return }

        var startIndex = 0
        while startIndex < recipes.count {
            let endIndex = min(startIndex + Self.importWriteBatchSize, recipes.count)

            var entityBatch: [ImportedRecipeEntities] = []
            entityBatch.reserveCapacity(endIndex - startIndex)

            for recipe in recipes[startIndex..<endIndex] {
                let entities = await Recipe.entites(from: recipe)
                entityBatch.append(entities)
            }

            try await saveImportedRecipes(entityBatch)
            startIndex = endIndex
        }

        scheduleImportedImageHydration(for: recipes)
    }

    public func saveImportedRecipes(_ entityBatch: [ImportedRecipeEntities]) async throws {
        guard !entityBatch.isEmpty else { return }

        var startIndex = 0
        while startIndex < entityBatch.count {
            let endIndex = min(startIndex + Self.importWriteBatchSize, entityBatch.count)
            let chunk = entityBatch[startIndex..<endIndex]
            try await insertImportedEntityBatch(chunk)
            startIndex = endIndex
        }
    }

    private func insertImportedEntityBatch(_ entityBatch: ArraySlice<ImportedRecipeEntities>) async throws {
        guard !entityBatch.isEmpty else { return }

        var recipes: [DBRecipe] = []
        var images: [DBRecipeImage] = []
        var ingredientGroups: [DBRecipeIngredientGroup] = []
        var ingredients: [DBRecipeIngredient] = []
        var stepGroups: [DBRecipeStepGroup] = []
        var steps: [DBRecipeStep] = []
        var timings: [DBRecipeStepTiming] = []
        var temperatures: [DBRecipeStepTemperature] = []
        var ratings: [DBRecipeRating] = []
        var linkedIngredients: [DBRecipeStepLinkedIngredient] = []

        recipes.reserveCapacity(entityBatch.count)
        images.reserveCapacity(entityBatch.count)

        for entities in entityBatch {
            let (recipe, image, recipeIngredientGroups, recipeIngredients, recipeStepGroups, recipeSteps, recipeTimings, recipeTemperatures, recipeRatings, recipeLinkedIngredients) = entities
            recipes.append(recipe)
            images.append(image)
            ingredientGroups.append(contentsOf: recipeIngredientGroups)
            ingredients.append(contentsOf: recipeIngredients)
            stepGroups.append(contentsOf: recipeStepGroups)
            steps.append(contentsOf: recipeSteps)
            timings.append(contentsOf: recipeTimings)
            temperatures.append(contentsOf: recipeTemperatures)
            ratings.append(contentsOf: recipeRatings)
            linkedIngredients.append(contentsOf: recipeLinkedIngredients)
        }

        let recipesBatch = recipes
        let imagesBatch = images
        let ingredientGroupsBatch = ingredientGroups
        let ingredientsBatch = ingredients
        let stepGroupsBatch = stepGroups
        let stepsBatch = steps
        let timingsBatch = timings
        let temperaturesBatch = temperatures
        let ratingsBatch = ratings
        let linkedIngredientsBatch = linkedIngredients

        try await database.write { db in
            try DBRecipe.insert { recipesBatch }.execute(db)
            try DBRecipeImage.insert { imagesBatch }.execute(db)
            try DBRecipeIngredientGroup.insert { ingredientGroupsBatch }.execute(db)
            try DBRecipeIngredient.insert { ingredientsBatch }.execute(db)
            try DBRecipeStepGroup.insert { stepGroupsBatch }.execute(db)
            try DBRecipeStep.insert { stepsBatch }.execute(db)
            try DBRecipeStepTiming.insert { timingsBatch }.execute(db)
            try DBRecipeStepTemperature.insert { temperaturesBatch }.execute(db)
            try DBRecipeRating.insert { ratingsBatch }.execute(db)
            try DBRecipeStepLinkedIngredient.insert { linkedIngredientsBatch }.execute(db)
        }
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

        scheduleImportedImageHydration(for: [recipe])
    }

    private struct PendingImportedImageHydration: Sendable {
        let recipeId: UUID
        let imageURL: String?
        let sourceURL: String
    }

    private func scheduleImportedImageHydration(for recipes: [Recipe]) {
        let pending = recipes.compactMap { recipe -> PendingImportedImageHydration? in
            guard recipe.image.imageThumbnailData == nil else { return nil }
            guard RecipeImagePersistenceSupport.shouldHydrateImportedImage(
                imageURL: recipe.image.imageUrl,
                sourceURL: recipe.sourceUrl
            ) else { return nil }

            return PendingImportedImageHydration(
                recipeId: recipe.id,
                imageURL: recipe.image.imageUrl,
                sourceURL: recipe.sourceUrl
            )
        }

        guard !pending.isEmpty else { return }

        Task(priority: .utility) { [weak self, pending] in
            await self?.hydrateImportedImages(pending)
        }
    }

    private func hydrateImportedImages(_ pending: [PendingImportedImageHydration]) async {
        let maxConcurrentFetches = Self.importImageHydrationFetchConcurrency
        var startIndex = 0
        var hydratedBuffer: [DBRecipeImage] = []
        hydratedBuffer.reserveCapacity(Self.importImageHydrationWriteBatchSize)

        while startIndex < pending.count {
            let endIndex = min(startIndex + maxConcurrentFetches, pending.count)
            let chunk = Array(pending[startIndex..<endIndex])
            var hydrated: [DBRecipeImage] = []
            hydrated.reserveCapacity(chunk.count)

            await withTaskGroup(of: (UUID, String?, Data)?.self) { group in
                for item in chunk {
                    group.addTask {
                        guard let data = await RecipeImagePersistenceSupport.resolveThumbnailData(
                            imageURL: item.imageURL,
                            sourceURL: item.sourceURL
                        ) else {
                            return nil
                        }

                        return (item.recipeId, item.imageURL, data)
                    }
                }

                for await result in group {
                    guard let result else { continue }
                    hydrated.append(
                        DBRecipeImage(
                            recipeId: result.0,
                            imageSourceUrl: result.1,
                            imageData: result.2
                        )
                    )
                }
            }

            if !hydrated.isEmpty {
                hydratedBuffer.append(contentsOf: hydrated)
            }

            if hydratedBuffer.count >= Self.importImageHydrationWriteBatchSize {
                let bufferedBatch = hydratedBuffer
                hydratedBuffer.removeAll(keepingCapacity: true)
                await persistHydratedImageBatch(bufferedBatch)
            }

            startIndex = endIndex
        }

        if !hydratedBuffer.isEmpty {
            let bufferedBatch = hydratedBuffer
            await persistHydratedImageBatch(bufferedBatch)
        }
    }

    private func persistHydratedImageBatch(_ batch: [DBRecipeImage]) async {
        guard !batch.isEmpty else { return }

        do {
            try await database.write { db in
                for image in batch {
                    try DBRecipeImage
                        .upsert { image }
                        .execute(db)
                }
            }
        } catch {
            print("Error hydrating imported images: \(error)")
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
