//
//  Recipe+Persistence.swift
//  Models
//
//  Created by Tom Knighton on 22/10/2025.
//

import Foundation
import Persistence

public extension FullDBRecipe {
    
    /**
            Coverts the db model to the domain Recipe struct
     */
    func toDomainModel() -> Recipe {
        let image = RecipeImage(imageThumbnailData: self.imageData?.imageData, imageUrl: self.imageData?.imageSourceUrl)
        let timing = RecipeTiming(totalTime: self.recipe.totalMins, prepTime: self.recipe.minutesToPrepare, cookTime: self.recipe.minutesToCook)
        let ratingInfo = RecipeRatingInfo(overallRating: self.recipe.overallRating, totalRatings: self.recipe.totalRatings, summarisedRating: self.recipe.summarisedRating, ratings: self.ratings.compactMap { RecipeRating(id: $0.id, rating: $0.rating, comment: $0.comment) })
        
        let ingredientSections = self.ingredientGroups.compactMap { grp in
            let ingredients = self.ingredients.filter { $0.ingredientGroupId == grp.id }.compactMap { ing in
                RecipeIngredient(id: ing.id, sortIndex: ing.sortIndex, ingredientText: ing.rawIngredient, ingredientPart: ing.ingredient, extraInformation: ing.extra, quantity: .init(quantity: ing.quantity, quantityText: ing.quantityText), unit: .init(unit: ing.unit, unitText: ing.unitText), emoji: ing.emojiDescriptor, owned: ing.owned)
            }
            
            return RecipeIngredientGroup(id: grp.id, title: grp.title, sortIndex: grp.sortIndex, ingredients: ingredients.sorted(by: { $0.sortIndex < $1.sortIndex }))
        }
        
        let allIngredientIds = self.ingredients.compactMap { $0.id }
        
        let stepSections = self.stepGroups.compactMap { grp in
            let steps = self.steps.filter { $0.groupId == grp.id }.compactMap { step in
                let timings = self.timings.filter { $0.recipeStepId == step.id }.map { RecipeStepTiming(id: $0.id, timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText) }
                let temps = self.temperatures.filter { $0.recipeStepId == step.id }.map { RecipeStepTemperature(id: $0.id, temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) }
                
                let ingredientIds = self.stepLinkedIngredients
                    .filter { $0.recipeStepId == step.id && allIngredientIds.contains($0.ingredientId) }
                    .sorted(by: { $0.sortIndex < $1.sortIndex })
                    .compactMap { $0.ingredientId }
                let step = RecipeStep(id: step.id, sortIndex: step.sortIndex, instructionText: step.instruction, timings: timings, temperatures: temps, linkedIngredients: ingredientIds)
                return step
            }
            
            return RecipeStepSection(id: grp.id, sortIndex: grp.sortIndex, title: grp.title, steps: steps)
        }
                
        return Recipe(id: self.recipe.id, title: self.recipe.title, description: self.recipe.description, summarisedTip: self.recipe.summarisedSuggestion, author: self.recipe.author, sourceUrl: self.recipe.sourceUrl, image: image, timing: timing, serves: self.recipe.serves, ratingInfo: ratingInfo, dateAdded: self.recipe.dateAdded, dateModified: self.recipe.dateModified, ingredientSections: ingredientSections, stepSections: stepSections, dominantColorHex: self.recipe.dominantColorHex, homeId: self.recipe.homeId)
    }
}

public extension RecipeIngredientGroup {
    func asDatabaseObject(for recipeId: Recipe.ID) -> DBRecipeIngredientGroup {
        return .init(id: self.id, recipeId: recipeId, title: self.title, sortIndex: self.sortIndex)
    }
    
    func ingredientsAsDatabaseObjects() -> [DBRecipeIngredient] {
        return ingredients.map { DBRecipeIngredient(id: $0.id, ingredientGroupId: self.id, sortIndex: $0.sortIndex, rawIngredient: $0.ingredientText, quantity: $0.quantity?.quantity, quantityText: $0.quantity?.quantityText, unit: $0.unit?.unit, unitText: $0.unit?.unitText, ingredient: $0.ingredientPart, extra: $0.extraInformation, emojiDescriptor: $0.emoji, owned: $0.owned ?? false) }
    }
}

public extension RecipeStepSection {
    func asDatabaseObject(for recipeId: Recipe.ID) -> DBRecipeStepGroup {
        return .init(id: self.id, recipeId: recipeId, title: self.title, sortIndex: self.sortIndex)
    }
    
    func stepsAsDatabaseObjects() -> [DBRecipeStep] {
        return steps.map { DBRecipeStep(id: $0.id, groupId: self.id, sortIndex: $0.sortIndex, instruction: $0.instructionText) }
    }
}
