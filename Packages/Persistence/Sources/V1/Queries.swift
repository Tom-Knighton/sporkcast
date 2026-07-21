//
//  Queries.swift
//  Persistence
//
//  Created by Tom Knighton on 20/10/2025.
//

import Foundation
import GRDB

public struct FullDBRecipe: Codable, FetchableRecord, Sendable, Identifiable, Equatable {
    public var recipe: DBRecipe
    public var imageData: DBRecipeImage?
    public var ingredientGroups: [DBRecipeIngredientGroup]
    public var ingredients: [DBRecipeIngredient]
    public var stepGroups: [DBRecipeStepGroup]
    public var steps: [DBRecipeStep]
    public var timings: [DBRecipeStepTiming]
    public var temperatures: [DBRecipeStepTemperature]
    public var ratings: [DBRecipeRating]
    public var stepLinkedIngredients: [DBRecipeStepLinkedIngredient]

    public var id: UUID { recipe.id }
}

public struct ListDBRecipe: Codable, FetchableRecord, Sendable, Identifiable, Equatable {
    public var recipe: DBRecipe
    public var imageData: DBRecipeImage?
    public var folders: [DBRecipeFolder]
    public var tags: [DBRecipeTag]

    public var id: UUID { recipe.id }
}

public struct FullDBMealplanEntry: Codable, FetchableRecord, Sendable, Identifiable, Equatable {
    public var mealplanEntry: DBMealplanEntry
    public var recipe: DBRecipe?
    public var image: DBRecipeImage?

    public var id: UUID { mealplanEntry.id }

    public init(mealplanEntry: DBMealplanEntry, recipe: DBRecipe?, image: DBRecipeImage?) {
        self.mealplanEntry = mealplanEntry
        self.recipe = recipe
        self.image = image
    }
}

public struct FullDBShoppingList: Codable, FetchableRecord, Sendable, Identifiable, Equatable {
    public var shoppingList: DBShoppingList
    public var items: [DBShoppingListItem]

    public var id: UUID { shoppingList.id }

    public init(shoppingList: DBShoppingList, items: [DBShoppingListItem]) {
        self.shoppingList = shoppingList
        self.items = items
    }
}

public extension DBRecipe {
    static var full: DBQuery<FullDBRecipe> {
        DBQuery<FullDBRecipe> { db, query in
            let recipes = try DBRecipe.all
                .where(query.condition ?? SQLCondition(sql: "1"))
                .order(by: \.dateModified)
                .fetchAll(db)

            guard !recipes.isEmpty else { return [] }

            let recipeIds = Set(recipes.map(\.id))
            let images = try DBRecipeImage.all.fetchAll(db).dictionaryById()
            let ingredientGroups = try DBRecipeIngredientGroup.all.fetchAll(db)
                .filter { recipeIds.contains($0.recipeId) }
                .sorted { $0.sortIndex < $1.sortIndex }
            let ingredientGroupIds = Set(ingredientGroups.map(\.id))
            let ingredients = try DBRecipeIngredient.all.fetchAll(db)
                .filter { ingredientGroupIds.contains($0.ingredientGroupId) }
                .sorted { $0.sortIndex < $1.sortIndex }
            let stepGroups = try DBRecipeStepGroup.all.fetchAll(db)
                .filter { recipeIds.contains($0.recipeId) }
                .sorted { $0.sortIndex < $1.sortIndex }
            let stepGroupIds = Set(stepGroups.map(\.id))
            let steps = try DBRecipeStep.all.fetchAll(db)
                .filter { stepGroupIds.contains($0.groupId) }
                .sorted { $0.sortIndex < $1.sortIndex }
            let stepIds = Set(steps.map(\.id))
            let timings = try DBRecipeStepTiming.all.fetchAll(db)
                .filter { stepIds.contains($0.recipeStepId) }
            let temperatures = try DBRecipeStepTemperature.all.fetchAll(db)
                .filter { stepIds.contains($0.recipeStepId) }
            let ratings = try DBRecipeRating.all.fetchAll(db)
                .filter { recipeIds.contains($0.recipeId) }
            let stepLinkedIngredients = try DBRecipeStepLinkedIngredient.all.fetchAll(db)
                .filter { stepIds.contains($0.recipeStepId) }
                .sorted { $0.sortIndex < $1.sortIndex }

            let ingredientGroupsByRecipe = Dictionary(grouping: ingredientGroups, by: \.recipeId)
            let ingredientsByGroup = Dictionary(grouping: ingredients, by: \.ingredientGroupId)
            let stepGroupsByRecipe = Dictionary(grouping: stepGroups, by: \.recipeId)
            let stepsByGroup = Dictionary(grouping: steps, by: \.groupId)
            let timingsByStep = Dictionary(grouping: timings, by: \.recipeStepId)
            let temperaturesByStep = Dictionary(grouping: temperatures, by: \.recipeStepId)
            let ratingsByRecipe = Dictionary(grouping: ratings, by: \.recipeId)
            let linkedIngredientsByStep = Dictionary(grouping: stepLinkedIngredients, by: \.recipeStepId)

            return recipes.map { recipe in
                let recipeIngredientGroups = ingredientGroupsByRecipe[recipe.id] ?? []
                let recipeIngredients = recipeIngredientGroups.flatMap { ingredientsByGroup[$0.id] ?? [] }
                let recipeStepGroups = stepGroupsByRecipe[recipe.id] ?? []
                let recipeSteps = recipeStepGroups.flatMap { stepsByGroup[$0.id] ?? [] }
                return FullDBRecipe(
                    recipe: recipe,
                    imageData: images[recipe.id],
                    ingredientGroups: recipeIngredientGroups,
                    ingredients: recipeIngredients,
                    stepGroups: recipeStepGroups,
                    steps: recipeSteps,
                    timings: recipeSteps.flatMap { timingsByStep[$0.id] ?? [] },
                    temperatures: recipeSteps.flatMap { temperaturesByStep[$0.id] ?? [] },
                    ratings: ratingsByRecipe[recipe.id] ?? [],
                    stepLinkedIngredients: recipeSteps.flatMap { linkedIngredientsByStep[$0.id] ?? [] }
                )
            }
        }
    }

    static var list: DBQuery<ListDBRecipe> {
        DBQuery<ListDBRecipe> { db, query in
            let recipes = try DBRecipe.all
                .where(query.condition ?? SQLCondition(sql: "1"))
                .order(by: \.dateModified)
                .fetchAll(db)
            guard !recipes.isEmpty else { return [] }

            let recipeIds = Set(recipes.map(\.id))
            let images = try DBRecipeImage.all.fetchAll(db).dictionaryById()
            let folderAssignments = try DBRecipeFolderAssignment.all.fetchAll(db)
                .filter { recipeIds.contains($0.recipeId) }
            let tagAssignments = try DBRecipeTagAssignment.all.fetchAll(db)
                .filter { recipeIds.contains($0.recipeId) }
            let folders = try DBRecipeFolder.all.fetchAll(db).dictionaryById()
            let tags = try DBRecipeTag.all.fetchAll(db).dictionaryById()
            let folderAssignmentsByRecipe = Dictionary(grouping: folderAssignments, by: \.recipeId)
            let tagAssignmentsByRecipe = Dictionary(grouping: tagAssignments, by: \.recipeId)

            return recipes.map { recipe in
                ListDBRecipe(
                    recipe: recipe,
                    imageData: images[recipe.id],
                    folders: (folderAssignmentsByRecipe[recipe.id] ?? []).compactMap { folders[$0.folderId] },
                    tags: (tagAssignmentsByRecipe[recipe.id] ?? []).compactMap { tags[$0.tagId] }
                )
            }
        }
    }
}

public extension DBMealplanEntry {
    static func full(startDate: Date, endDate: Date) -> DBQuery<FullDBMealplanEntry> {
        full.where { $0.date >= startDate && $0.date <= endDate }
    }
    
    static func full(ids: [DBMealplanEntry.ID]) -> DBQuery<FullDBMealplanEntry> {
        full.where { ids.contains($0.id) }
    }
    
    static func full(lookup: String) -> DBQuery<FullDBMealplanEntry> {
        DBQuery<FullDBMealplanEntry> { db, query in
            let matchingRecipeIds = Set(
                try DBRecipe.all
                    .fetchAll(db)
                    .filter { $0.title.localizedCaseInsensitiveContains(lookup) }
                    .map(\.id)
            )

            let entries = try DBMealplanEntry.all
                .where((query.condition ?? SQLCondition(sql: "1")) && matchingRecipeIds.contains(DBColumn(name: "recipeId")))
                .order(by: \.date)
                .fetchAll(db)
            let recipeIds = Set(entries.compactMap(\.recipeId))
            let recipes = try DBRecipe.all.fetchAll(db)
                .filter { recipeIds.contains($0.id) }
                .dictionaryById()
            let images = try DBRecipeImage.all.fetchAll(db).dictionaryById()

            return entries.map { entry in
                FullDBMealplanEntry(
                    mealplanEntry: entry,
                    recipe: entry.recipeId.flatMap { recipes[$0] },
                    image: entry.recipeId.flatMap { images[$0] }
                )
            }
        }
    }

    static var full: DBQuery<FullDBMealplanEntry> {
        DBQuery<FullDBMealplanEntry> { db, query in
            let entries = try DBMealplanEntry.all
                .where(query.condition ?? SQLCondition(sql: "1"))
                .order(by: \.date)
                .fetchAll(db)
            let recipeIds = Set(entries.compactMap(\.recipeId))
            let recipes = try DBRecipe.all.fetchAll(db)
                .filter { recipeIds.contains($0.id) }
                .dictionaryById()
            let images = try DBRecipeImage.all.fetchAll(db).dictionaryById()

            return entries.map { entry in
                FullDBMealplanEntry(
                    mealplanEntry: entry,
                    recipe: entry.recipeId.flatMap { recipes[$0] },
                    image: entry.recipeId.flatMap { images[$0] }
                )
            }
        }
    }
}

public extension DBShoppingList {
    static var full: DBQuery<FullDBShoppingList> {
        DBQuery<FullDBShoppingList> { db, query in
            let lists = try DBShoppingList.all
                .where(query.condition ?? SQLCondition(sql: "1"))
                .fetchAll(db)
            guard !lists.isEmpty else { return [] }

            let listIds = Set(lists.map(\.id))
            let itemsByList = Dictionary(
                grouping: try DBShoppingListItem.all.fetchAll(db)
                    .filter { listIds.contains($0.listId) },
                by: \.listId
            )

            return lists.map { list in
                FullDBShoppingList(shoppingList: list, items: itemsByList[list.id] ?? [])
            }
        }
    }
}

private extension Sequence where Element: Identifiable, Element.ID == UUID {
    func dictionaryById() -> [UUID: Element] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0) })
    }
}
