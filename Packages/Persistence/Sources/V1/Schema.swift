//
//  DBRecipe.swift
//  Persistence
//
//  Created by Tom Knighton on 20/10/2025.
//

import Foundation
import SQLiteData

@Table("Recipes")
public struct DBRecipe: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let author: String?
    public let sourceUrl: String
    public let dominantColorHex: String?
    public let minutesToPrepare: Double?
    public let minutesToCook: Double?
    public let totalMins: Double?
    public let serves: String?
    public let overallRating: Double?
    public let summarisedRating: String?
    public let summarisedSuggestion: String?
    public let dateAdded: Date
    public let dateModified: Date
    
    public let homeId: UUID?
    
    public init(id: UUID, title: String, description: String?, author: String?, sourceUrl: String, dominantColorHex: String?, minutesToPrepare: Double?, minutesToCook: Double?, totalMins: Double?, serves: String?, overallRating: Double?, summarisedRating: String?, summarisedSuggestion: String?, dateAdded: Date, dateModified: Date, homeId: UUID?) {
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
        self.summarisedRating = summarisedRating
        self.summarisedSuggestion = summarisedSuggestion
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.homeId = homeId
    }
}

@Table("RecipeImages")
public struct DBRecipeImage: Codable, Identifiable, Sendable, Equatable {
    
    @Column(primaryKey: true)
    public let recipeId: DBRecipe.ID
    public let imageSourceUrl: String?
    public var imageData: Data?
    
    public var id: DBRecipe.ID { recipeId }
    
    public init(recipeId: DBRecipe.ID, imageSourceUrl: String?, imageData: Data?) {
        self.recipeId = recipeId
        self.imageSourceUrl = imageSourceUrl
        self.imageData = imageData
    }
}

@Table("RecipeIngredientGroups")
public struct DBRecipeIngredientGroup: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let recipeId: UUID
    public let title: String
    public let sortIndex: Int
    
    public init(id: UUID, recipeId: UUID, title: String, sortIndex: Int) {
        self.id = id
        self.recipeId = recipeId
        self.title = title
        self.sortIndex = sortIndex
    }
}

@Table("RecipeIngredients")
public struct DBRecipeIngredient: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let ingredientGroupId: UUID
    public let sortIndex: Int
    public let rawIngredient: String
    public let quantity: Double?
    public let quantityText: String?
    public let unit: String?
    public let unitText: String?
    public let ingredient: String?
    public let extra: String?
    public let emojiDescriptor: String?
    public let owned: Bool
    
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

@Table("RecipeStepGroups")
public struct DBRecipeStepGroup: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let recipeId: UUID
    public let title: String
    public let sortIndex: Int
    
    public init(id: UUID, recipeId: UUID, title: String, sortIndex: Int) {
        self.id = id
        self.recipeId = recipeId
        self.title = title
        self.sortIndex = sortIndex
    }
}

@Table("RecipeSteps")
public struct DBRecipeStep: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let groupId: UUID
    public let sortIndex: Int
    public let instruction: String
    
    public init(id: UUID, groupId: UUID, sortIndex: Int, instruction: String) {
        self.id = id
        self.groupId = groupId
        self.sortIndex = sortIndex
        self.instruction = instruction
    }
}

@Table("RecipeStepTimings")
public struct DBRecipeStepTiming: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let recipeStepId: UUID
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

@Table("RecipeStepTemperatures")
public struct DBRecipeStepTemperature: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let recipeStepId: UUID
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

@Table("Homes")
public struct DBHome: Codable, Identifiable, Sendable, Equatable {
    @Column(primaryKey: true)
    public let id: UUID
    public let name: String
    
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

@Table("MealplanEntries")
public struct DBMealplanEntry: Codable, Identifiable, Sendable, Equatable {
    @Column(primaryKey: true)
    public let id: UUID
    public let date: Date
    public let index: Int
    public let noteText: String?
    public let recipeId: UUID?
    public let homeId: UUID?
    
    public init(id: UUID, date: Date, index: Int, noteText: String?, recipeId: UUID?, homeId: UUID?) {
        self.id = id
        self.date = date
        self.index = index
        self.noteText = noteText
        self.recipeId = recipeId
        self.homeId = homeId
    }
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
            
            try db.create(table: "MealplanEntries") { e in
                e.primaryKey("id", .text)
                e.column("date", .date)
                e.column("index", .integer)
                e.column("noteText", .text)
                e.column("recipeId", .text)
                e.column("homeId", .text).references("Homes", onDelete: .setNull)
            }
        }
    }
}
