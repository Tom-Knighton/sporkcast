//
//  DBRecipe.swift
//  Persistence
//
//  Created by Tom Knighton on 20/10/2025.
//

import Foundation
import SQLiteData

@Table("Recipes")
public struct DBRecipe {
    public let id: UUID
    public let title: String
    public let description: String
    public let author: String
    public let sourceUrl: String
    public let imageAssetFileName: String?
    public let thumbnailData: Data?
    public let imageUrl: String?
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
    
    public init(id: UUID, title: String, description: String, author: String, sourceUrl: String, imageAssetFileName: String?, thumbnailData: Data?, imageUrl: String?, dominantColorHex: String?, minutesToPrepare: Double?, minutesToCook: Double?, totalMins: Double?, serves: String?, overallRating: Double?, summarisedRating: String?, summarisedSuggestion: String?, dateAdded: Date, dateModified: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.author = author
        self.sourceUrl = sourceUrl
        self.imageAssetFileName = imageAssetFileName
        self.thumbnailData = thumbnailData
        self.imageUrl = imageUrl
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
    }
}

@Table("RecipeIngredientGroups")
public struct DBRecipeIngredientGroup: Codable, Identifiable {
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
public struct DBRecipeIngredient: Codable, Identifiable {
    public let id: UUID
    public let ingredientGroupId: UUID
    public let sortIndex: Int
    public let rawIndex: String
    public let quantity: Double?
    public let quantityText: String?
    public let unit: String?
    public let unitText: String?
    public let ingredient: String?
    public let extra: String?
    public let emojiDescriptor: String?
    public let owned: Bool
    
    public init(id: UUID, ingredientGroupId: UUID, sortIndex: Int, rawIndex: String, quantity: Double?, quantityText: String?, unit: String?, unitText: String?, ingredient: String?, extra: String?, emojiDescriptor: String?, owned: Bool) {
        self.id = id
        self.ingredientGroupId = ingredientGroupId
        self.sortIndex = sortIndex
        self.rawIndex = rawIndex
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
public struct DBRecipeStepGroup: Codable, Identifiable {
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
public struct DBRecipeStep: Codable, Identifiable {
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
public struct DBRecipeStepTiming: Codable, Identifiable {
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

@Table("RecipeStepTemperature")
public struct DBRecipeStepTemperature: Codable, Identifiable {
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
