//
//  RecipesRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Models
import Observation
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
    private var recipesObservation: AnyDatabaseCancellable?

    private var dbRecipes: [ListDBRecipe] = []

    public var recipes: [Recipe] {
        dbRecipes.compactMap { $0.toDomainModel() }
    }

    public func recipesForDuplicateMatching() async -> [Recipe] {
        do {
            let fullRecipes = try await database.read { db in
                try DBRecipe.full.fetchAll(db)
            }
            return fullRecipes.map { $0.toDomainModel() }
        } catch {
            return recipes
        }
    }

    public init(observesChanges: Bool = true) {
        guard observesChanges else { return }

        recipesObservation = observeAll(database, query: DBRecipe.list) { error in
            RecipeDebugDiagnostics.logAppEvent("recipes observation failed error=\(error)")
        } onChange: { [weak self] recipes in
            self?.dbRecipes = recipes
        }
    }
    
    public func getById(_ ids: [Recipe.ID]) async throws -> [Recipe] {
        let dbRecipes: [FullDBRecipe] = try await database.read { db in
            try DBRecipe
                .full
                .where { ids.contains($0.id) }
                .fetchAll(db)
        }
        
        let recipe = dbRecipes.compactMap { $0.toDomainModel() }
        return recipe
    }
    
    public func getByLookup(_ lookup: String) async throws -> [Recipe] {
        let trimmedLookup = lookup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLookup.isEmpty else {
            return try await getAllRecipes()
        }

        let dbRecipes: [FullDBRecipe] = try await database.read { db in
            try DBRecipe
                .full
                .where { [$0.title, $0.author, $0.description].containsText(trimmedLookup) }
                .fetchAll(db)
        }
        
        var recipesById = Dictionary(uniqueKeysWithValues: dbRecipes.map { ($0.id, $0.toDomainModel()) })
        for recipe in try await getAllRecipes() where recipe.matchesLookup(trimmedLookup) {
            recipesById[recipe.id] = recipe
        }

        return recipesById.values.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    public func getAllRecipes() async throws -> [Recipe] {
        try await database.read { db in
            try DBRecipe
                .full
                .fetchAll(db)
                .map { $0.toDomainModel() }
        }
    }

    public func getIntentSuggestions(limit: Int = 20) async throws -> [RecipeIntentSummary] {
        try await database.read { db in
            let recipes = try DBRecipe.all
                .order(by: \.dateModified)
                .fetchAll(db)
                .prefix(limit)
            let imageURLStringsByRecipeId = try Self.imageURLStringsByRecipeId(for: Set(recipes.map(\.id)), in: db)

            return recipes.map { recipe in
                Self.intentSummary(recipe: recipe, ingredientNames: [], imageURLString: imageURLStringsByRecipeId[recipe.id])
            }
        }
    }

    public func getIntentSummariesById(_ ids: [Recipe.ID]) async throws -> [RecipeIntentSummary] {
        guard !ids.isEmpty else { return [] }

        return try await database.read { db in
            let recipes = try DBRecipe.all
                .where { ids.contains($0.id) }
                .fetchAll(db)

            let ingredientNamesByRecipeId = try Self.ingredientNamesByRecipeId(for: Set(ids), in: db)
            let imageURLStringsByRecipeId = try Self.imageURLStringsByRecipeId(for: Set(ids), in: db)
            return recipes.map { recipe in
                Self.intentSummary(
                    recipe: recipe,
                    ingredientNames: ingredientNamesByRecipeId[recipe.id] ?? [],
                    imageURLString: imageURLStringsByRecipeId[recipe.id]
                )
            }
        }
    }

    public func getIntentSummariesByLookup(
        _ lookup: String,
        limit: Int = 8,
        returnsSuggestionsForEmptyLookup: Bool = true
    ) async throws -> [RecipeIntentSummary] {
        let trimmedLookup = lookup.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookupTokens = RecipeSearchNormalizer.tokens(for: trimmedLookup)
        guard !lookupTokens.isEmpty else {
            return returnsSuggestionsForEmptyLookup
                ? try await getIntentSuggestions(limit: limit)
                : []
        }

        return try await database.read { db in
            let recipes = try DBRecipe.all.fetchAll(db)
            let matchingRecipeIdsFromRecipeRows = Set(
                recipes
                    .filter { recipe in
                        [
                            recipe.title,
                            recipe.description,
                            recipe.author,
                            recipe.serves,
                            recipe.summarisedSuggestion
                        ]
                        .compactMap { $0 }
                        .contains { RecipeSearchNormalizer.matches($0, tokens: lookupTokens) }
                    }
                    .map(\.id)
            )

            let ingredientGroups = try DBRecipeIngredientGroup.all.fetchAll(db)
            let recipeIdByIngredientGroupId = Dictionary(uniqueKeysWithValues: ingredientGroups.map { ($0.id, $0.recipeId) })
            let ingredients = try DBRecipeIngredient.all.fetchAll(db)

            var ingredientNamesByRecipeId: [UUID: [String]] = [:]
            var matchingRecipeIdsFromIngredients: Set<UUID> = []

            for ingredient in ingredients {
                guard let recipeId = recipeIdByIngredientGroupId[ingredient.ingredientGroupId] else { continue }

                let ingredientValues = [
                    ingredient.rawIngredient,
                    ingredient.ingredient,
                    ingredient.extra
                ].compactMap { $0 }

                ingredientNamesByRecipeId[recipeId, default: []].append(ingredient.rawIngredient)

                if ingredientValues.contains(where: { RecipeSearchNormalizer.matches($0, tokens: lookupTokens) }) {
                    matchingRecipeIdsFromIngredients.insert(recipeId)
                }
            }

            let matchingRecipeIds = matchingRecipeIdsFromRecipeRows.union(matchingRecipeIdsFromIngredients)
            let matchingRecipes = Array(
                recipes
                    .filter { matchingRecipeIds.contains($0.id) }
                    .sorted {
                        $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    }
                    .prefix(limit)
            )
            let imageURLStringsByRecipeId = try Self.imageURLStringsByRecipeId(for: Set(matchingRecipes.map(\.id)), in: db)
            let imageDataByRecipeId = try Self.imageDataByRecipeId(for: Set(matchingRecipes.map(\.id)), in: db)

            return matchingRecipes
                .map { recipe in
                    Self.intentSummary(
                        recipe: recipe,
                        ingredientNames: ingredientNamesByRecipeId[recipe.id] ?? [],
                        imageURLString: imageURLStringsByRecipeId[recipe.id],
                        imageData: imageDataByRecipeId[recipe.id]
                    )
                }
        }
    }

    public func deleteAll() async throws {
        RecipeDebugDiagnostics.logAppEvent("deleteAllRecipes requested")
        await RecipeDebugDiagnostics.logRecipeCounts("before deleteAllRecipes", database: database)
        try await database.write { db in
            try RecipeManualCascade.deleteAllRecipeLinkedData(in: db)
            try DBRecipe.delete().execute(db)
        }
        RecipeSpotlightEvents.requestDeleteAll()
        await RecipeDebugDiagnostics.logRecipeCounts("after deleteAllRecipes", database: database)
    }
    
    public func delete(_ id: Recipe.ID) async throws  {
        RecipeDebugDiagnostics.logAppEvent("deleteRecipe requested recipeId=\(id)")
        await RecipeDebugDiagnostics.logRecipeCounts("before deleteRecipe recipeId=\(id)", database: database)
        let deletionContext = try await database.read { db in
            (
                homeId: try DBRecipe.find(id).fetchOne(db)?.homeId,
                mealplanEntryIds: try DBMealplanEntry
                    .where { $0.recipeId.eq(id) }
                    .select(\.id)
                    .fetchAll(db)
            )
        }
        try await database.write { db in
            try RecipeManualCascade.deleteRecipeLinkedData(for: id, in: db)
            try DBRecipe.find(id).delete().execute(db)
            try DBMealplanEntry.where { $0.recipeId.eq(id) }.delete().execute(db)
        }
        RecipeSpotlightEvents.requestDelete(ids: [id])
        MealplanSpotlightEvents.requestDelete(ids: deletionContext.mealplanEntryIds)
        await SupabaseSyncService.shared.deleteRecipe(id, homeId: deletionContext.homeId)
        await RecipeDebugDiagnostics.logRecipeCounts("after deleteRecipe recipeId=\(id)", database: database)
    }

    public func saveImportedRecipe(_ entities: ImportedRecipeEntities) async throws {
        try await saveImportedRecipes([entities])
    }

    public func saveImportedRecipe(_ recipe: Recipe) async throws {
        try await saveImportedRecipes([recipe])
    }

    public func saveImportedRecipes(_ recipes: [Recipe]) async throws {
        guard !recipes.isEmpty else { return }

        RecipeDebugDiagnostics.logAppEvent("saveImportedRecipes domainCount=\(recipes.count) ids=\(recipes.map(\.id).map(\.uuidString).joined(separator: ","))")
        await RecipeDebugDiagnostics.logRecipeCounts("before saveImportedRecipes domainCount=\(recipes.count)", database: database)

        var entityBatch: [ImportedRecipeEntities] = []
        entityBatch.reserveCapacity(recipes.count)

        var startIndex = 0
        while startIndex < recipes.count {
            let endIndex = min(startIndex + Self.importWriteBatchSize, recipes.count)

            for recipe in recipes[startIndex..<endIndex] {
                let entities = await Recipe.entites(from: recipe)
                entityBatch.append(entities)
            }

            startIndex = endIndex
        }

        try await saveImportedRecipes(entityBatch)
        await RecipeDebugDiagnostics.logRecipeCounts("after saveImportedRecipes domainCount=\(recipes.count)", database: database)
        scheduleImportedImageHydration(for: recipes)
    }

    public func saveImportedRecipes(_ entityBatch: [ImportedRecipeEntities]) async throws {
        guard !entityBatch.isEmpty else { return }

        let recipeIDs = entityBatch.map { $0.0.id.uuidString }.joined(separator: ",")
        RecipeDebugDiagnostics.logAppEvent("saveImportedRecipeEntities count=\(entityBatch.count) ids=\(recipeIDs)")
        await RecipeDebugDiagnostics.logRecipeCounts("before saveImportedRecipeEntities count=\(entityBatch.count)", database: database)

        var startIndex = 0
        while startIndex < entityBatch.count {
            let endIndex = min(startIndex + Self.importWriteBatchSize, entityBatch.count)
            let chunk = entityBatch[startIndex..<endIndex]
            RecipeDebugDiagnostics.logAppEvent("insertImportedEntityBatch range=\(startIndex)..<\(endIndex) count=\(chunk.count)")
            try await insertImportedEntityBatch(chunk)
            await RecipeDebugDiagnostics.logRecipeCounts("after insertImportedEntityBatch range=\(startIndex)..<\(endIndex)", database: database)
            startIndex = endIndex
        }

        let supabaseRecipes = entityBatch.map { ($0.0.id, $0.0.homeId) }
        RecipeSpotlightEvents.requestIndex(ids: entityBatch.map { $0.0.id })
        Task(priority: .utility) { [weak self, supabaseRecipes] in
            await self?.syncSupabaseRecipeUpserts(supabaseRecipes)
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
        RecipeDebugDiagnostics.logAppEvent("replaceImportedRecipe requested recipeId=\(existingRecipeId)")
        await RecipeDebugDiagnostics.logRecipeCounts("before replaceImportedRecipe recipeId=\(existingRecipeId)", database: database)

        let recipe = importedRecipe.copy(id: existingRecipeId)
        let entities = await Recipe.entites(from: recipe)

        let (newRecipe, newImage, newIngGroups, newIngs, newStepGroups, newSteps, newStepTimings, newStepTemps, newRatings, newLinkedIngredients) = entities
        let shouldReplaceIngredients = !newIngGroups.isEmpty && !newIngs.isEmpty
        let shouldReplaceSteps = !newStepGroups.isEmpty && !newSteps.isEmpty

        try await database.write { db in
            try DBRecipe
                .upsert { newRecipe }
                .execute(db)

            try DBRecipeImage
                .upsert { newImage }
                .execute(db)

            if shouldReplaceIngredients {
                RecipeDebugDiagnostics.logAppEvent("replaceImportedRecipe deleting ingredients recipeId=\(existingRecipeId)")
                try RecipeManualCascade.deleteIngredientLinkedData(for: existingRecipeId, in: db)
            } else {
                print("Skipping ingredient replacement for \(existingRecipeId) due to incomplete import payload")
            }

            if shouldReplaceSteps {
                RecipeDebugDiagnostics.logAppEvent("replaceImportedRecipe deleting steps recipeId=\(existingRecipeId)")
                try RecipeManualCascade.deleteStepLinkedData(for: existingRecipeId, in: db)
            } else {
                print("Skipping step replacement for \(existingRecipeId) due to incomplete import payload")
            }

            try DBRecipeRating
                .where { $0.recipeId.eq(existingRecipeId) }
                .delete()
                .execute(db)

            if shouldReplaceIngredients {
                try DBRecipeIngredientGroup
                    .insert { newIngGroups }
                    .execute(db)

                try DBRecipeIngredient
                    .insert { newIngs }
                    .execute(db)
            }

            if shouldReplaceSteps {
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
            }

            try DBRecipeRating
                .insert { newRatings }
                .execute(db)
        }

        await RecipeDebugDiagnostics.logRecipeCounts("after replaceImportedRecipe recipeId=\(existingRecipeId)", database: database)
        RecipeSpotlightEvents.requestIndex(ids: [newRecipe.id])
        await syncSupabaseRecipeUpserts([(newRecipe.id, newRecipe.homeId)])
        scheduleImportedImageHydration(for: [recipe])
    }

    private func syncSupabaseRecipeUpserts(_ recipes: [(id: UUID, homeId: UUID?)]) async {
        guard !recipes.isEmpty else { return }

        do {
            try await SupabaseSyncService.shared.pushRecipes(recipeIds: recipes.map(\.id))
            return
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase direct recipe batch push failed count=\(recipes.count) error=\(error)")
        }

        for recipe in recipes {
            await SupabaseSyncService.shared.enqueueRecipeUpsert(recipeId: recipe.id, homeId: recipe.homeId)
        }

        await SupabaseSyncService.shared.drainOutbox(limit: max(20, recipes.count))
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

        RecipeDebugDiagnostics.logAppEvent("scheduleImportedImageHydration count=\(pending.count) recipeIds=\(pending.map(\.recipeId).map(\.uuidString).joined(separator: ","))")
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
            RecipeDebugDiagnostics.logAppEvent("persistHydratedImageBatch count=\(batch.count) recipeIds=\(batch.map(\.recipeId).map(\.uuidString).joined(separator: ","))")
            try await database.write { db in
                for image in batch {
                    try DBRecipeImage
                        .upsert { image }
                        .execute(db)
                }
            }
            await RecipeDebugDiagnostics.logRecipeCounts("after persistHydratedImageBatch count=\(batch.count)", database: database)
            RecipeSpotlightEvents.requestIndex(ids: batch.map(\.recipeId))
            do {
                try await SupabaseSyncService.shared.pushRecipes(recipeIds: batch.map(\.recipeId))
            } catch {
                RecipeDebugDiagnostics.logAppEvent("supabase hydrated image push failed count=\(batch.count) error=\(error)")
            }
        } catch {
            RecipeDebugDiagnostics.logAppEvent("persistHydratedImageBatch failed count=\(batch.count) error=\(error)")
            print("Error hydrating imported images: \(error)")
        }
    }
}

private extension RecipesRepository {
    nonisolated static func ingredientNamesByRecipeId(for recipeIds: Set<UUID>, in db: Database) throws -> [UUID: [String]] {
        guard !recipeIds.isEmpty else { return [:] }

        let ingredientGroups = try DBRecipeIngredientGroup.all.fetchAll(db)
            .filter { recipeIds.contains($0.recipeId) }
        let recipeIdByIngredientGroupId = Dictionary(uniqueKeysWithValues: ingredientGroups.map { ($0.id, $0.recipeId) })
        let ingredientGroupIds = Set(ingredientGroups.map(\.id))
        let ingredients = try DBRecipeIngredient.all.fetchAll(db)
            .filter { ingredientGroupIds.contains($0.ingredientGroupId) }

        var ingredientNamesByRecipeId: [UUID: [String]] = [:]
        for ingredient in ingredients {
            guard let recipeId = recipeIdByIngredientGroupId[ingredient.ingredientGroupId] else { continue }
            ingredientNamesByRecipeId[recipeId, default: []].append(ingredient.rawIngredient)
        }
        return ingredientNamesByRecipeId
    }

    nonisolated static func imageURLStringsByRecipeId(for recipeIds: Set<UUID>, in db: Database) throws -> [UUID: String] {
        guard !recipeIds.isEmpty else { return [:] }

        let placeholders = Array(repeating: "?", count: recipeIds.count).joined(separator: ", ")
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT recipeId, imageSourceUrl FROM RecipeImages WHERE recipeId IN (\(placeholders)) AND imageSourceUrl IS NOT NULL",
            arguments: StatementArguments(recipeIds.map(\.uuidString))
        )

        var imageURLStringsByRecipeId: [UUID: String] = [:]
        for row in rows {
            guard let idString: String = row["recipeId"],
                  let recipeId = UUID(uuidString: idString),
                  let imageURLString: String = row["imageSourceUrl"],
                  !imageURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            imageURLStringsByRecipeId[recipeId] = imageURLString
        }

        return imageURLStringsByRecipeId
    }

    nonisolated static func imageDataByRecipeId(for recipeIds: Set<UUID>, in db: Database) throws -> [UUID: Data] {
        guard !recipeIds.isEmpty else { return [:] }

        let placeholders = Array(repeating: "?", count: recipeIds.count).joined(separator: ", ")
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT recipeId, imageData FROM RecipeImages WHERE recipeId IN (\(placeholders)) AND imageData IS NOT NULL",
            arguments: StatementArguments(recipeIds.map(\.uuidString))
        )

        var imageDataByRecipeId: [UUID: Data] = [:]
        for row in rows {
            guard let idString: String = row["recipeId"],
                  let recipeId = UUID(uuidString: idString),
                  let imageData: Data = row["imageData"],
                  !imageData.isEmpty else {
                continue
            }

            imageDataByRecipeId[recipeId] = imageData
        }

        return imageDataByRecipeId
    }

    nonisolated static func intentSummary(recipe: DBRecipe, ingredientNames: [String]) -> RecipeIntentSummary {
        intentSummary(recipe: recipe, ingredientNames: ingredientNames, imageURLString: nil)
    }

    nonisolated static func intentSummary(recipe: DBRecipe, ingredientNames: [String], imageURLString: String?, imageData: Data? = nil) -> RecipeIntentSummary {
        let keywords = [
            recipe.title,
            recipe.description,
            recipe.author,
            recipe.serves,
            recipe.summarisedSuggestion
        ]
        .compactMap { $0 }
        + ingredientNames

        return RecipeIntentSummary(
            id: recipe.id,
            title: recipe.title,
            summary: recipe.description,
            author: recipe.author,
            keywords: Array(Set(keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })),
            ingredientNames: ingredientNames,
            totalMinutes: recipe.totalMins,
            prepMinutes: recipe.minutesToPrepare,
            serves: recipe.serves,
            imageURLString: imageURLString,
            imageData: imageData
        )
    }
}

private extension Recipe {
    func matchesLookup(_ lookup: String) -> Bool {
        let searchableValues = [
            title,
            description,
            author,
            serves,
            summarisedTip
        ].compactMap { $0 }
            + ingredientSections.flatMap(\.ingredients).flatMap {
                [$0.ingredientText, $0.ingredientPart, $0.extraInformation].compactMap { $0 }
            }
            + stepSections.flatMap(\.steps).map(\.instructionText)
            + tags.map(\.name)
            + folders.map(\.name)

        return searchableValues.contains {
            $0.localizedCaseInsensitiveContains(lookup)
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
            ingredientScale: ingredientScale,
            ingredientUnitSystem: ingredientUnitSystem,
            homeId: homeId
        )
    }
}
