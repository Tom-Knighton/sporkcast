//
//  SporkastRecipeExportPayload.swift
//  Environment
//
//  Created by Tom Knighton on 03/04/2026.
//

import Foundation
import Persistence

public struct SporkastRecipeExportPayload: Codable, Sendable, Identifiable, Equatable {
    public let schemaVersion: Int
    public let exportFormat: String
    public let exportedAt: Date

    public let recipe: DBRecipeRecord
    public let image: DBRecipeImage?
    public let ingredientGroups: [DBRecipeIngredientGroup]
    public let ingredients: [DBRecipeIngredient]
    public let stepGroups: [DBRecipeStepGroup]
    public let steps: [DBRecipeStep]
    public let stepTimings: [DBRecipeStepTiming]
    public let stepTemperatures: [DBRecipeStepTemperature]
    public let ratings: [DBRecipeRating]
    public let stepLinkedIngredients: [DBRecipeStepLinkedIngredient]

    public var id: UUID { recipe.id }

    public init(recipe fullRecipe: FullDBRecipe, exportedAt: Date, schemaVersion: Int) {
        self.schemaVersion = schemaVersion
        self.exportFormat = RecipeExportFormat.sporkast.rawValue
        self.exportedAt = exportedAt

        let sortedIngredientGroups = fullRecipe.ingredientGroups.sorted(by: DBRecipeIngredientGroup.sortOrder)
        let ingredientGroupSortIndexByID = Dictionary(uniqueKeysWithValues: sortedIngredientGroups.map { ($0.id, $0.sortIndex) })

        let sortedStepGroups = fullRecipe.stepGroups.sorted(by: DBRecipeStepGroup.sortOrder)
        let stepGroupSortIndexByID = Dictionary(uniqueKeysWithValues: sortedStepGroups.map { ($0.id, $0.sortIndex) })
        let stepSortIndexByID = Dictionary(uniqueKeysWithValues: fullRecipe.steps.map { ($0.id, $0.sortIndex) })

        self.recipe = .init(fullRecipe.recipe)
        self.image = fullRecipe.imageData
        self.ingredientGroups = sortedIngredientGroups
        self.ingredients = fullRecipe.ingredients.sorted {
            let lhsGroupSort = ingredientGroupSortIndexByID[$0.ingredientGroupId] ?? .max
            let rhsGroupSort = ingredientGroupSortIndexByID[$1.ingredientGroupId] ?? .max
            if lhsGroupSort != rhsGroupSort {
                return lhsGroupSort < rhsGroupSort
            }
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        self.stepGroups = sortedStepGroups
        self.steps = fullRecipe.steps.sorted {
            let lhsGroupSort = stepGroupSortIndexByID[$0.groupId] ?? .max
            let rhsGroupSort = stepGroupSortIndexByID[$1.groupId] ?? .max
            if lhsGroupSort != rhsGroupSort {
                return lhsGroupSort < rhsGroupSort
            }
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        self.stepTimings = fullRecipe.timings.sorted {
            let lhsStepSort = stepSortIndexByID[$0.recipeStepId] ?? .max
            let rhsStepSort = stepSortIndexByID[$1.recipeStepId] ?? .max
            if lhsStepSort != rhsStepSort {
                return lhsStepSort < rhsStepSort
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        self.stepTemperatures = fullRecipe.temperatures.sorted {
            let lhsStepSort = stepSortIndexByID[$0.recipeStepId] ?? .max
            let rhsStepSort = stepSortIndexByID[$1.recipeStepId] ?? .max
            if lhsStepSort != rhsStepSort {
                return lhsStepSort < rhsStepSort
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        self.ratings = fullRecipe.ratings.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        self.stepLinkedIngredients = fullRecipe.stepLinkedIngredients.sorted {
            let lhsStepSort = stepSortIndexByID[$0.recipeStepId] ?? .max
            let rhsStepSort = stepSortIndexByID[$1.recipeStepId] ?? .max
            if lhsStepSort != rhsStepSort {
                return lhsStepSort < rhsStepSort
            }
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

public extension SporkastRecipeExportPayload {
    struct DBRecipeRecord: Codable, Sendable, Equatable {
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
        public let totalRatings: Int
        public let summarisedRating: String?
        public let summarisedSuggestion: String?
        public let dateAdded: Date
        public let dateModified: Date
        public let homeId: UUID?

        public init(_ recipe: DBRecipe) {
            self.id = recipe.id
            self.title = recipe.title
            self.description = recipe.description
            self.author = recipe.author
            self.sourceUrl = recipe.sourceUrl
            self.dominantColorHex = recipe.dominantColorHex
            self.minutesToPrepare = recipe.minutesToPrepare
            self.minutesToCook = recipe.minutesToCook
            self.totalMins = recipe.totalMins
            self.serves = recipe.serves
            self.overallRating = recipe.overallRating
            self.totalRatings = recipe.totalRatings
            self.summarisedRating = recipe.summarisedRating
            self.summarisedSuggestion = recipe.summarisedSuggestion
            self.dateAdded = recipe.dateAdded
            self.dateModified = recipe.dateModified
            self.homeId = recipe.homeId
        }
    }
}

private extension DBRecipeIngredientGroup {
    static func sortOrder(lhs: DBRecipeIngredientGroup, rhs: DBRecipeIngredientGroup) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private extension DBRecipeStepGroup {
    static func sortOrder(lhs: DBRecipeStepGroup, rhs: DBRecipeStepGroup) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
