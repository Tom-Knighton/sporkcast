//
//  DBRecipe.swift
//  Persistence
//
//  Created by Tom Knighton on 20/10/2025.
//

import Foundation
import GRDB

public struct DBRecipe: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var description: String?
    public var author: String?
    public var sourceUrl: String
    public var dominantColorHex: String?
    public var minutesToPrepare: Double?
    public var minutesToCook: Double?
    public var totalMins: Double?
    public var serves: String?
    public var overallRating: Double?
    public var totalRatings: Int
    public var summarisedRating: String?
    public var summarisedSuggestion: String?
    public var dateAdded: Date
    public var dateModified: Date
    public var ingredientScale: Double
    public var ingredientUnitSystem: String
    
    public var homeId: UUID?
    
    public init(id: UUID, title: String, description: String?, author: String?, sourceUrl: String, dominantColorHex: String?, minutesToPrepare: Double?, minutesToCook: Double?, totalMins: Double?, serves: String?, overallRating: Double?, totalRatings: Int, summarisedRating: String?, summarisedSuggestion: String?, dateAdded: Date, dateModified: Date, ingredientScale: Double = 1.0, ingredientUnitSystem: String = "original", homeId: UUID?) {
        self.id = id
        self.title = title
        self.description = description
        self.author = author
        self.sourceUrl = sourceUrl
        self.dominantColorHex = dominantColorHex
        self.minutesToPrepare = minutesToPrepare
        self.minutesToCook = minutesToCook
        self.totalMins = totalMins
        self.serves = serves
        self.overallRating = overallRating
        self.totalRatings = totalRatings
        self.summarisedRating = summarisedRating
        self.summarisedSuggestion = summarisedSuggestion
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.ingredientScale = ingredientScale
        self.ingredientUnitSystem = ingredientUnitSystem
        self.homeId = homeId
    }
}

public struct DBRecipeImage: Codable, Identifiable, Sendable, Equatable {
    
    public var recipeId: DBRecipe.ID
    public var imageSourceUrl: String?
    public var imageData: Data?
    
    public var id: DBRecipe.ID { recipeId }
    
    public init(recipeId: DBRecipe.ID, imageSourceUrl: String?, imageData: Data?) {
        self.recipeId = recipeId
        self.imageSourceUrl = imageSourceUrl
        self.imageData = imageData
    }
}

public struct DBRecipeIngredientGroup: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeId: UUID
    public var title: String
    public var sortIndex: Int
    
    public init(id: UUID, recipeId: UUID, title: String, sortIndex: Int) {
        self.id = id
        self.recipeId = recipeId
        self.title = title
        self.sortIndex = sortIndex
    }
}

public struct DBRecipeIngredient: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var ingredientGroupId: UUID
    public var sortIndex: Int
    public var rawIngredient: String
    public var quantity: Double?
    public var quantityText: String?
    public var unit: String?
    public var unitText: String?
    public var ingredient: String?
    public var extra: String?
    public var emojiDescriptor: String?
    public var owned: Bool
    
    public init(id: UUID, ingredientGroupId: UUID, sortIndex: Int, rawIngredient: String, quantity: Double?, quantityText: String?, unit: String?, unitText: String?, ingredient: String?, extra: String?, emojiDescriptor: String?, owned: Bool) {
        self.id = id
        self.ingredientGroupId = ingredientGroupId
        self.sortIndex = sortIndex
        self.rawIngredient = rawIngredient
        self.quantity = quantity
        self.quantityText = quantityText
        self.unit = unit
        self.unitText = unitText
        self.ingredient = ingredient
        self.extra = extra
        self.emojiDescriptor = emojiDescriptor
        self.owned = owned
    }
}

public struct DBRecipeStepGroup: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeId: UUID
    public var title: String
    public var sortIndex: Int
    
    public init(id: UUID, recipeId: UUID, title: String, sortIndex: Int) {
        self.id = id
        self.recipeId = recipeId
        self.title = title
        self.sortIndex = sortIndex
    }
}

public struct DBRecipeStep: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var groupId: UUID
    public var sortIndex: Int
    public var instruction: String
    
    public init(id: UUID, groupId: UUID, sortIndex: Int, instruction: String) {
        self.id = id
        self.groupId = groupId
        self.sortIndex = sortIndex
        self.instruction = instruction
    }
}

public struct DBRecipeStepTiming: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeStepId: UUID
    public var timeInSeconds: Double
    public var timeText: String
    public var timeUnitText: String
    
    public init(id: UUID, recipeStepId: UUID, timeInSeconds: Double, timeText: String, timeUnitText: String) {
        self.id = id
        self.recipeStepId = recipeStepId
        self.timeInSeconds = timeInSeconds
        self.timeText = timeText
        self.timeUnitText = timeUnitText
    }
}

public struct DBRecipeStepTemperature: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeStepId: UUID
    public var temperature: Double
    public var temperatureText: String
    public var temperatureUnitText: String
    
    public init(id: UUID, recipeStepId: UUID, temperature: Double, temperatureText: String, temperatureUnitText: String) {
        self.id = id
        self.recipeStepId = recipeStepId
        self.temperature = temperature
        self.temperatureText = temperatureText
        self.temperatureUnitText = temperatureUnitText
    }
}

public struct DBRecipeStepLinkedIngredient: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeStepId: UUID
    public var ingredientId: UUID
    public var sortIndex: Int
    
    public init(id: UUID, recipeStepId: UUID, ingredientId: UUID, sortIndex: Int) {
        self.id = id
        self.recipeStepId = recipeStepId
        self.ingredientId = ingredientId
        self.sortIndex = sortIndex
    }
}

public struct DBRecipeRating: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeId: UUID
    public var rating: Int?
    public var comment: String?
    
    public init(id: UUID, recipeId: UUID, rating: Int?, comment: String?) {
        self.id = id
        self.recipeId = recipeId
        self.rating = rating
        self.comment = comment
    }
}

public struct DBRecipeFolder: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var homeId: UUID?
    public var name: String
    public var symbolName: String
    public var colorHex: String
    public var sortIndex: Int
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID,
        homeId: UUID?,
        name: String,
        symbolName: String,
        colorHex: String,
        sortIndex: Int,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.homeId = homeId
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct DBRecipeFolderHierarchy: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var parentFolderId: UUID
    public var childFolderId: UUID

    public init(id: UUID, parentFolderId: UUID, childFolderId: UUID) {
        self.id = id
        self.parentFolderId = parentFolderId
        self.childFolderId = childFolderId
    }
}

public struct DBRecipeTag: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var homeId: UUID?
    public var name: String
    public var colorHex: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID,
        homeId: UUID?,
        name: String,
        colorHex: String,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.homeId = homeId
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct DBRecipeFolderAssignment: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeId: UUID
    public var folderId: UUID
    public var assignedAt: Date

    public init(id: UUID, recipeId: UUID, folderId: UUID, assignedAt: Date) {
        self.id = id
        self.recipeId = recipeId
        self.folderId = folderId
        self.assignedAt = assignedAt
    }
}

public struct DBRecipeTagAssignment: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var recipeId: UUID
    public var tagId: UUID
    public var assignedAt: Date

    public init(id: UUID, recipeId: UUID, tagId: UUID, assignedAt: Date) {
        self.id = id
        self.recipeId = recipeId
        self.tagId = tagId
        self.assignedAt = assignedAt
    }
}

public struct DBHome: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DBMealplanEntry: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var date: Date
    public var index: Int
    public var noteText: String?
    public var recipeId: UUID?
    public var homeId: UUID?
    
    public init(id: UUID, date: Date, index: Int, noteText: String?, recipeId: UUID?, homeId: UUID?) {
        self.id = id
        self.date = date
        self.index = index
        self.noteText = noteText
        self.recipeId = recipeId
        self.homeId = homeId
    }
}

public struct DBShoppingList: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var homeId: UUID?
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var isArchived: Bool
    
    public init(id: UUID, homeId: UUID?, title: String, createdAt: Date, modifiedAt: Date, isArchived: Bool) {
        self.id = id
        self.homeId = homeId
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isArchived = isArchived
    }
}

public struct DBShoppingListItem: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var listId: DBShoppingList.ID
    public var isComplete: Bool
    public var modifiedAt: Date
    
    public var categoryIdentifier: String?
    public var categoryDisplayName: String
    public var categorySource: String
    
    public init(
        id: UUID,
        title: String,
        listId: DBShoppingList.ID,
        isComplete: Bool,
        modifiedAt: Date = .now,
        categoryIdentifier: String?,
        categoryDisplayName: String,
        categorySource: String
    ) {
        self.id = id
        self.listId = listId
        self.title = title
        self.isComplete = isComplete
        self.modifiedAt = modifiedAt
        self.categoryIdentifier = categoryIdentifier
        self.categoryDisplayName = categoryDisplayName
        self.categorySource = categorySource
    }
}

public struct DBShoppingListItemIngredientLink: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var shoppingListItemId: DBShoppingListItem.ID
    public var ingredientId: UUID
    public var sourceScale: Double?
    public var addedAt: Date

    public init(
        id: UUID,
        shoppingListItemId: DBShoppingListItem.ID,
        ingredientId: UUID,
        sourceScale: Double?,
        addedAt: Date
    ) {
        self.id = id
        self.shoppingListItemId = shoppingListItemId
        self.ingredientId = ingredientId
        self.sourceScale = sourceScale
        self.addedAt = addedAt
    }
}

public struct DBShoppingListItemMealplanLink: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var shoppingListItemId: DBShoppingListItem.ID
    public var mealplanEntryId: UUID
    public var addedAt: Date

    public init(
        id: UUID,
        shoppingListItemId: DBShoppingListItem.ID,
        mealplanEntryId: UUID,
        addedAt: Date
    ) {
        self.id = id
        self.shoppingListItemId = shoppingListItemId
        self.mealplanEntryId = mealplanEntryId
        self.addedAt = addedAt
    }
}

public struct DBShoppingListItemReminderLink: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var shoppingListItemId: DBShoppingListItem.ID
    public var reminderIdentifier: String
    public var reminderExternalIdentifier: String?
    public var lastSyncedAt: Date

    public init(
        id: UUID,
        shoppingListItemId: DBShoppingListItem.ID,
        reminderIdentifier: String,
        reminderExternalIdentifier: String?,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.shoppingListItemId = shoppingListItemId
        self.reminderIdentifier = reminderIdentifier
        self.reminderExternalIdentifier = reminderExternalIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct DBMealplanEntryCalendarEventLink: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var mealplanEntryId: UUID
    public var eventIdentifier: String
    public var eventExternalIdentifier: String?
    public var lastSyncedAt: Date

    public init(
        id: UUID,
        mealplanEntryId: UUID,
        eventIdentifier: String,
        eventExternalIdentifier: String?,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.mealplanEntryId = mealplanEntryId
        self.eventIdentifier = eventIdentifier
        self.eventExternalIdentifier = eventExternalIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct DBSupabaseOutboxMutation: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var kind: String
    public var entityId: UUID?
    public var homeId: UUID?
    public var operation: String
    public var createdAt: Date
    public var attemptCount: Int
    public var lastAttemptAt: Date?
    public var lastError: String?

    public init(
        id: UUID,
        kind: String,
        entityId: UUID?,
        homeId: UUID?,
        operation: String,
        createdAt: Date,
        attemptCount: Int,
        lastAttemptAt: Date?,
        lastError: String?
    ) {
        self.id = id
        self.kind = kind
        self.entityId = entityId
        self.homeId = homeId
        self.operation = operation
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.lastError = lastError
    }
}

extension DBRecipe: DBRecord {
    public static let databaseTableName = "Recipes"
}

extension DBRecipeImage: DBRecord {
    public static let databaseTableName = "RecipeImages"
    public static let idColumnName = "recipeId"
}

extension DBRecipeIngredientGroup: DBRecord {
    public static let databaseTableName = "RecipeIngredientGroups"
}

extension DBRecipeIngredient: DBRecord {
    public static let databaseTableName = "RecipeIngredients"
}

extension DBRecipeStepGroup: DBRecord {
    public static let databaseTableName = "RecipeStepGroups"
}

extension DBRecipeStep: DBRecord {
    public static let databaseTableName = "RecipeSteps"
}

extension DBRecipeStepTiming: DBRecord {
    public static let databaseTableName = "RecipeStepTimings"
}

extension DBRecipeStepTemperature: DBRecord {
    public static let databaseTableName = "RecipeStepTemperatures"
}

extension DBRecipeStepLinkedIngredient: DBRecord {
    public static let databaseTableName = "RecipeStepLinkedIngredients"
}

extension DBRecipeRating: DBRecord {
    public static let databaseTableName = "RecipeRatings"
}

extension DBRecipeFolder: DBRecord {
    public static let databaseTableName = "RecipeFolders"
}

extension DBRecipeFolderHierarchy: DBRecord {
    public static let databaseTableName = "RecipeFolderHierarchy"
}

extension DBRecipeTag: DBRecord {
    public static let databaseTableName = "RecipeTags"
}

extension DBRecipeFolderAssignment: DBRecord {
    public static let databaseTableName = "RecipeFolderAssignments"
}

extension DBRecipeTagAssignment: DBRecord {
    public static let databaseTableName = "RecipeTagAssignments"
}

extension DBHome: DBRecord {
    public static let databaseTableName = "Homes"
}

extension DBMealplanEntry: DBRecord {
    public static let databaseTableName = "MealplanEntries"
}

extension DBShoppingList: DBRecord {
    public static let databaseTableName = "ShoppingLists"
}

extension DBShoppingListItem: DBRecord {
    public static let databaseTableName = "ShoppingListItems"
}

extension DBShoppingListItemIngredientLink: DBRecord {
    public static let databaseTableName = "ShoppingListItemIngredientLinks"
}

extension DBShoppingListItemMealplanLink: DBRecord {
    public static let databaseTableName = "ShoppingListItemMealplanLinks"
}

extension DBShoppingListItemReminderLink: DBRecord {
    public static let databaseTableName = "ShoppingListItemReminderLinks"
}

extension DBMealplanEntryCalendarEventLink: DBRecord {
    public static let databaseTableName = "MealplanEntryCalendarEventLinks"
}

extension DBSupabaseOutboxMutation: DBRecord {
    public static let databaseTableName = "SupabaseOutboxMutations"
}

public struct SchemaV1 {
    public static func migrate(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Create Tables") { db in
            
            try db.create(table: "Homes") { e in
                e.primaryKey("id", .text)
                e.column("name", .text).notNull()
            }
            
            try db.create(table: "Recipes") { e in
                e.primaryKey("id", .text)
                e.column("title", .text)
                    .notNull()
                e.column("description", .text)
                e.column("author", .text)
                e.column("sourceUrl", .text).notNull()
                e.column("imageAssetFileName", .text)
                e.column("thumbnailData", .blob)
                e.column("imageUrl", .text)
                e.column("dominantColorHex", .text)
                e.column("minutesToPrepare", .double)
                e.column("minutesToCook", .double)
                e.column("totalMins", .double)
                e.column("serves", .text)
                e.column("overallRating", .double)
                e.column("totalRatings", .integer)
                e.column("summarisedRating", .text)
                e.column("summarisedSuggestion", .text)
                e.column("dateAdded", .date)
                e.column("dateModified", .date)
                e.column("homeId", .text).references("Homes", onDelete: .setNull)
            }
            
            try db.create(table: "RecipeImages") { e in
                e.primaryKey("recipeId", .text).references("Recipes", onDelete: .cascade)
                e.column("imageData", .blob)
                e.column("imageSourceUrl", .text)
            }
            
            try db.create(table: "RecipeIngredientGroups") { e in
                e.primaryKey("id", .text)
                e.column("recipeId", .text).notNull().references("Recipes", onDelete: .cascade)
                e.column("title", .text).notNull()
                e.column("sortIndex", .integer).notNull()
            }
            
            try db.create(table: "RecipeIngredients") { e in
                e.primaryKey("id", .text)
                e.column("ingredientGroupId", .text).notNull().references("RecipeIngredientGroups", onDelete: .cascade)
                e.column("sortIndex", .integer).notNull()
                e.column("rawIngredient", .text).notNull()
                e.column("quantity", .integer)
                e.column("quantityText", .text)
                e.column("unit", .text)
                e.column("unitText", .text)
                e.column("ingredient", .text)
                e.column("extra", .text)
                e.column("emojiDescriptor", .text)
                e.column("owned", .boolean)
            }
            
            try db.create(table: "RecipeStepGroups") { e in
                e.primaryKey("id", .text)
                e.column("recipeId", .text).notNull().references("Recipes", onDelete: .cascade)
                e.column("title", .text).notNull()
                e.column("sortIndex", .integer).notNull()
            }
            
            try db.create(table: "RecipeSteps") { e in
                e.primaryKey("id", .text)
                e.column("groupId", .text).notNull().references("RecipeStepGroups", onDelete: .cascade)
                e.column("sortIndex", .integer).notNull()
                e.column("instruction", .text).notNull()
            }
            
            try db.create(table: "RecipeStepTimings") { e in
                e.primaryKey("id", .text)
                e.column("recipeStepId", .text).references("RecipeSteps", onDelete: .cascade)
                e.column("timeInSeconds", .double).notNull()
                e.column("timeText", .text).notNull()
                e.column("timeUnitText", .text).notNull()
            }
            
            try db.create(table: "RecipeStepTemperatures") { e in
                e.primaryKey("id", .text)
                e.column("recipeStepId", .text).references("RecipeSteps", onDelete: .cascade)
                e.column("temperature", .double).notNull()
                e.column("temperatureText", .text).notNull( )
                e.column("temperatureUnitText", .text).notNull()
            }
            
            try db.create(table: "RecipeStepLinkedIngredients") { e in
                e.primaryKey("id", .text)
                e.column("recipeStepId", .text).references("RecipeSteps", onDelete: .cascade)
                e.column("ingredientId", .text)
                e.column("sortIndex", .integer)
            }
            
            try db.create(table: "RecipeRatings") { e in
                e.primaryKey("id", .text)
                e.column("recipeId", .text).references("Recipes", onDelete: .cascade)
                e.column("rating", .integer)
                e.column("comment", .text)
            }
            
            try db.create(table: "MealplanEntries") { e in
                e.primaryKey("id", .text)
                e.column("date", .date)
                e.column("index", .integer)
                e.column("noteText", .text)
                e.column("recipeId", .text)
                e.column("homeId", .text).references("Homes", onDelete: .setNull)
            }

            try db.create(table: "ShoppingLists") { e in
                e.primaryKey("id", .text)
                e.column("homeId").references("Homes", onDelete: .setNull)
                e.column("title", .text).notNull()
                e.column("createdAt", .date).notNull()
                e.column("modifiedAt", .date)
                e.column("isArchived", .boolean).defaults(to: false)
            }
            
            try db.create(table: "ShoppingListItems") { e in
                e.primaryKey("id", .text)
                e.column("listId", .text).references("ShoppingLists", onDelete: .cascade)
                e.column("title", .text).notNull()
                e.column("isComplete", .boolean).notNull().defaults(to: false)
                
                e.column("categoryIdentifier", .text)
                    .notNull()
                    .defaults(to: "unknown")
                    .indexed()
                
                e.column("categoryDisplayName", .text).notNull().defaults(to: "Other")
                e.column("categorySource", .text)
            }
        }

        migrator.registerMigration("Add Recipe Ingredient Scale") { db in
            try db.alter(table: "Recipes") { e in
                e.add(column: "ingredientScale", .double).notNull().defaults(to: 1.0)
            }
        }

        migrator.registerMigration("Add Recipe Ingredient Unit System") { db in
            try db.alter(table: "Recipes") { e in
                e.add(column: "ingredientUnitSystem", .text).notNull().defaults(to: "original")
            }
        }

        migrator.registerMigration("Create Shopping Item Link Tables") { db in
            try db.create(table: "ShoppingListItemIngredientLinks") { e in
                e.primaryKey("id", .text)
                e.column("shoppingListItemId", .text)
                    .notNull()
                    .references("ShoppingListItems", onDelete: .cascade)
                e.column("ingredientId", .text).notNull()
                e.column("sourceScale", .double)
                e.column("addedAt", .date).notNull()
            }

            try db.create(table: "ShoppingListItemMealplanLinks") { e in
                e.primaryKey("id", .text)
                e.column("shoppingListItemId", .text)
                    .notNull()
                    .references("ShoppingListItems", onDelete: .cascade)
                e.column("mealplanEntryId", .text).notNull()
                e.column("addedAt", .date).notNull()
            }
        }

        migrator.registerMigration("Create Shopping Reminder Sync Tables") { db in
            try db.alter(table: "ShoppingListItems") { e in
                // Use a deterministic default so DEBUG schema-change detection doesn't
                // think the schema changed on every launch and wipe local data.
                e.add(column: "modifiedAt", .date).notNull().defaults(to: Date(timeIntervalSince1970: 0))
            }

            try db.create(table: "ShoppingListItemReminderLinks") { e in
                e.primaryKey("id", .text)
                e.column("shoppingListItemId", .text)
                    .notNull()
                    .references("ShoppingListItems", onDelete: .cascade)
                e.column("reminderIdentifier", .text).notNull().indexed()
                e.column("reminderExternalIdentifier", .text).indexed()
                e.column("lastSyncedAt", .date).notNull()
            }
        }

        migrator.registerMigration("Create Recipe Organization Tables") { db in
            try db.create(table: "RecipeFolders") { e in
                e.primaryKey("id", .text)
                e.column("homeId", .text).references("Homes", onDelete: .cascade).indexed()
                e.column("name", .text).notNull()
                e.column("symbolName", .text).notNull().defaults(to: "folder")
                e.column("colorHex", .text).notNull().defaults(to: "#F59E0B")
                e.column("sortIndex", .integer).notNull().defaults(to: 0)
                e.column("createdAt", .date).notNull()
                e.column("modifiedAt", .date).notNull()
            }

            try db.create(table: "RecipeTags") { e in
                e.primaryKey("id", .text)
                e.column("homeId", .text).references("Homes", onDelete: .cascade).indexed()
                e.column("name", .text).notNull()
                e.column("colorHex", .text).notNull().defaults(to: "#2563EB")
                e.column("createdAt", .date).notNull()
                e.column("modifiedAt", .date).notNull()
            }

            try db.create(table: "RecipeFolderAssignments") { e in
                e.primaryKey("id", .text)
                e.column("recipeId", .text).notNull().references("Recipes", onDelete: .cascade).indexed()
                e.column("folderId", .text).notNull().references("RecipeFolders", onDelete: .cascade).indexed()
                e.column("assignedAt", .date).notNull()
            }

            try db.create(table: "RecipeTagAssignments") { e in
                e.primaryKey("id", .text)
                e.column("recipeId", .text).notNull().references("Recipes", onDelete: .cascade).indexed()
                e.column("tagId", .text).notNull().references("RecipeTags", onDelete: .cascade).indexed()
                e.column("assignedAt", .date).notNull()
            }
        }

        migrator.registerMigration("Create Recipe Folder Hierarchy") { db in
            try db.create(table: "RecipeFolderHierarchy") { e in
                e.primaryKey("id", .text)
                e.column("parentFolderId", .text).notNull().references("RecipeFolders", onDelete: .cascade).indexed()
                e.column("childFolderId", .text).notNull().references("RecipeFolders", onDelete: .cascade).indexed()
            }
        }

        migrator.registerMigration("Create Mealplan Calendar Sync Tables") { db in
            try db.create(table: "MealplanEntryCalendarEventLinks") { e in
                e.primaryKey("id", .text)
                e.column("mealplanEntryId", .text)
                    .notNull()
                    .indexed()
                e.column("eventIdentifier", .text).notNull().indexed()
                e.column("eventExternalIdentifier", .text).indexed()
                e.column("lastSyncedAt", .date).notNull()
            }
        }

        migrator.registerMigration("Repair Mealplan Calendar Sync Table") { db in
            try db.execute(sql: """
                CREATE TABLE MealplanEntryCalendarEventLinks_repaired (
                    id TEXT PRIMARY KEY NOT NULL,
                    mealplanEntryId TEXT NOT NULL,
                    eventIdentifier TEXT NOT NULL,
                    eventExternalIdentifier TEXT,
                    lastSyncedAt DATE NOT NULL
                )
                """)

            try db.execute(sql: """
                INSERT INTO MealplanEntryCalendarEventLinks_repaired (
                    id,
                    mealplanEntryId,
                    eventIdentifier,
                    eventExternalIdentifier,
                    lastSyncedAt
                )
                SELECT
                    id,
                    mealplanEntryId,
                    eventIdentifier,
                    eventExternalIdentifier,
                    lastSyncedAt
                FROM MealplanEntryCalendarEventLinks
                """)

            try db.execute(sql: "DROP TABLE MealplanEntryCalendarEventLinks")
            try db.execute(sql: "ALTER TABLE MealplanEntryCalendarEventLinks_repaired RENAME TO MealplanEntryCalendarEventLinks")
            try db.execute(sql: "CREATE INDEX MealplanEntryCalendarEventLinks_on_mealplanEntryId ON MealplanEntryCalendarEventLinks(mealplanEntryId)")
            try db.execute(sql: "CREATE INDEX MealplanEntryCalendarEventLinks_on_eventIdentifier ON MealplanEntryCalendarEventLinks(eventIdentifier)")
            try db.execute(sql: "CREATE INDEX MealplanEntryCalendarEventLinks_on_eventExternalIdentifier ON MealplanEntryCalendarEventLinks(eventExternalIdentifier)")
        }

        migrator.registerMigration("Repair Recipe Folders Self Reference") { db in
            try db.execute(sql: """
                CREATE TABLE RecipeFolders_repaired (
                    id TEXT PRIMARY KEY NOT NULL,
                    homeId TEXT REFERENCES Homes(id) ON DELETE CASCADE,
                    name TEXT NOT NULL,
                    symbolName TEXT NOT NULL DEFAULT 'folder',
                    colorHex TEXT NOT NULL DEFAULT '#F59E0B',
                    sortIndex INTEGER NOT NULL DEFAULT 0,
                    createdAt DATE NOT NULL,
                    modifiedAt DATE NOT NULL
                )
                """)

            try db.execute(sql: """
                INSERT INTO RecipeFolders_repaired (
                    id,
                    homeId,
                    name,
                    symbolName,
                    colorHex,
                    sortIndex,
                    createdAt,
                    modifiedAt
                )
                SELECT
                    id,
                    homeId,
                    name,
                    symbolName,
                    colorHex,
                    sortIndex,
                    createdAt,
                    modifiedAt
                FROM RecipeFolders
                """)

            try db.execute(sql: "DROP TABLE RecipeFolders")
            try db.execute(sql: "ALTER TABLE RecipeFolders_repaired RENAME TO RecipeFolders")
            try db.execute(sql: "CREATE INDEX RecipeFolders_on_homeId ON RecipeFolders(homeId)")
        }

        migrator.registerMigration("Repair Duplicate Recipe Folder Hierarchy") { db in
            try db.execute(sql: """
                DELETE FROM RecipeFolderHierarchy
                WHERE rowid NOT IN (
                    SELECT MIN(rowid)
                    FROM RecipeFolderHierarchy
                    GROUP BY childFolderId
                )
                """)
        }

        migrator.registerMigration("Create Supabase Outbox Tables") { db in
            try db.create(table: "SupabaseOutboxMutations") { e in
                e.primaryKey("id", .text)
                e.column("kind", .text).notNull().indexed()
                e.column("entityId", .text).indexed()
                e.column("homeId", .text).indexed()
                e.column("operation", .text).notNull()
                e.column("createdAt", .date).notNull().indexed()
                e.column("attemptCount", .integer).notNull().defaults(to: 0)
                e.column("lastAttemptAt", .date)
                e.column("lastError", .text)
            }
        }

//        migrator.registerMigration("Remove Recipe Detail Cascade Constraints") { db in
//            try db.execute(sql: """
//                CREATE TABLE RecipeStepLinkedIngredients_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    recipeStepId TEXT,
//                    ingredientId TEXT,
//                    sortIndex INTEGER
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeStepLinkedIngredients_repaired (id, recipeStepId, ingredientId, sortIndex)
//                SELECT id, recipeStepId, ingredientId, sortIndex
//                FROM RecipeStepLinkedIngredients
//                """)
//            try db.execute(sql: "DROP TABLE RecipeStepLinkedIngredients")
//            try db.execute(sql: "ALTER TABLE RecipeStepLinkedIngredients_repaired RENAME TO RecipeStepLinkedIngredients")
//            try db.execute(sql: "CREATE INDEX RecipeStepLinkedIngredients_on_recipeStepId ON RecipeStepLinkedIngredients(recipeStepId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeStepTemperatures_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    recipeStepId TEXT,
//                    temperature DOUBLE NOT NULL,
//                    temperatureText TEXT NOT NULL,
//                    temperatureUnitText TEXT NOT NULL
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeStepTemperatures_repaired (id, recipeStepId, temperature, temperatureText, temperatureUnitText)
//                SELECT id, recipeStepId, temperature, temperatureText, temperatureUnitText
//                FROM RecipeStepTemperatures
//                """)
//            try db.execute(sql: "DROP TABLE RecipeStepTemperatures")
//            try db.execute(sql: "ALTER TABLE RecipeStepTemperatures_repaired RENAME TO RecipeStepTemperatures")
//            try db.execute(sql: "CREATE INDEX RecipeStepTemperatures_on_recipeStepId ON RecipeStepTemperatures(recipeStepId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeStepTimings_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    recipeStepId TEXT,
//                    timeInSeconds DOUBLE NOT NULL,
//                    timeText TEXT NOT NULL,
//                    timeUnitText TEXT NOT NULL
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeStepTimings_repaired (id, recipeStepId, timeInSeconds, timeText, timeUnitText)
//                SELECT id, recipeStepId, timeInSeconds, timeText, timeUnitText
//                FROM RecipeStepTimings
//                """)
//            try db.execute(sql: "DROP TABLE RecipeStepTimings")
//            try db.execute(sql: "ALTER TABLE RecipeStepTimings_repaired RENAME TO RecipeStepTimings")
//            try db.execute(sql: "CREATE INDEX RecipeStepTimings_on_recipeStepId ON RecipeStepTimings(recipeStepId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeSteps_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    groupId TEXT NOT NULL,
//                    sortIndex INTEGER NOT NULL,
//                    instruction TEXT NOT NULL
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeSteps_repaired (id, groupId, sortIndex, instruction)
//                SELECT id, groupId, sortIndex, instruction
//                FROM RecipeSteps
//                """)
//            try db.execute(sql: "DROP TABLE RecipeSteps")
//            try db.execute(sql: "ALTER TABLE RecipeSteps_repaired RENAME TO RecipeSteps")
//            try db.execute(sql: "CREATE INDEX RecipeSteps_on_groupId ON RecipeSteps(groupId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeStepGroups_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    recipeId TEXT NOT NULL,
//                    title TEXT NOT NULL,
//                    sortIndex INTEGER NOT NULL
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeStepGroups_repaired (id, recipeId, title, sortIndex)
//                SELECT id, recipeId, title, sortIndex
//                FROM RecipeStepGroups
//                """)
//            try db.execute(sql: "DROP TABLE RecipeStepGroups")
//            try db.execute(sql: "ALTER TABLE RecipeStepGroups_repaired RENAME TO RecipeStepGroups")
//            try db.execute(sql: "CREATE INDEX RecipeStepGroups_on_recipeId ON RecipeStepGroups(recipeId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeIngredients_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    ingredientGroupId TEXT NOT NULL,
//                    sortIndex INTEGER NOT NULL,
//                    rawIngredient TEXT NOT NULL,
//                    quantity INTEGER,
//                    quantityText TEXT,
//                    unit TEXT,
//                    unitText TEXT,
//                    ingredient TEXT,
//                    extra TEXT,
//                    emojiDescriptor TEXT,
//                    owned BOOLEAN
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeIngredients_repaired (
//                    id,
//                    ingredientGroupId,
//                    sortIndex,
//                    rawIngredient,
//                    quantity,
//                    quantityText,
//                    unit,
//                    unitText,
//                    ingredient,
//                    extra,
//                    emojiDescriptor,
//                    owned
//                )
//                SELECT
//                    id,
//                    ingredientGroupId,
//                    sortIndex,
//                    rawIngredient,
//                    quantity,
//                    quantityText,
//                    unit,
//                    unitText,
//                    ingredient,
//                    extra,
//                    emojiDescriptor,
//                    owned
//                FROM RecipeIngredients
//                """)
//            try db.execute(sql: "DROP TABLE RecipeIngredients")
//            try db.execute(sql: "ALTER TABLE RecipeIngredients_repaired RENAME TO RecipeIngredients")
//            try db.execute(sql: "CREATE INDEX RecipeIngredients_on_ingredientGroupId ON RecipeIngredients(ingredientGroupId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeIngredientGroups_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    recipeId TEXT NOT NULL,
//                    title TEXT NOT NULL,
//                    sortIndex INTEGER NOT NULL
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeIngredientGroups_repaired (id, recipeId, title, sortIndex)
//                SELECT id, recipeId, title, sortIndex
//                FROM RecipeIngredientGroups
//                """)
//            try db.execute(sql: "DROP TABLE RecipeIngredientGroups")
//            try db.execute(sql: "ALTER TABLE RecipeIngredientGroups_repaired RENAME TO RecipeIngredientGroups")
//            try db.execute(sql: "CREATE INDEX RecipeIngredientGroups_on_recipeId ON RecipeIngredientGroups(recipeId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeRatings_repaired (
//                    id TEXT PRIMARY KEY NOT NULL,
//                    recipeId TEXT,
//                    rating INTEGER,
//                    comment TEXT
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeRatings_repaired (id, recipeId, rating, comment)
//                SELECT id, recipeId, rating, comment
//                FROM RecipeRatings
//                """)
//            try db.execute(sql: "DROP TABLE RecipeRatings")
//            try db.execute(sql: "ALTER TABLE RecipeRatings_repaired RENAME TO RecipeRatings")
//            try db.execute(sql: "CREATE INDEX RecipeRatings_on_recipeId ON RecipeRatings(recipeId)")
//
//            try db.execute(sql: """
//                CREATE TABLE RecipeImages_repaired (
//                    recipeId TEXT PRIMARY KEY NOT NULL,
//                    imageData BLOB,
//                    imageSourceUrl TEXT
//                )
//                """)
//            try db.execute(sql: """
//                INSERT INTO RecipeImages_repaired (recipeId, imageData, imageSourceUrl)
//                SELECT recipeId, imageData, imageSourceUrl
//                FROM RecipeImages
//                """)
//            try db.execute(sql: "DROP TABLE RecipeImages")
//            try db.execute(sql: "ALTER TABLE RecipeImages_repaired RENAME TO RecipeImages")
//        }
    }
}
