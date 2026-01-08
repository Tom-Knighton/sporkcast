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
            
            return RecipeIngredientGroup(id: grp.id, title: grp.title, sortIndex: grp.sortIndex, ingredients: ingredients)
        }
        
        let stepSections = self.stepGroups.compactMap { grp in
            let steps = self.steps.filter { $0.groupId == grp.id }.compactMap { step in
                let timings = self.timings.filter { $0.recipeStepId == step.id }.map { RecipeStepTiming(id: $0.id, timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText) }
                let temps = self.temperatures.filter { $0.recipeStepId == step.id }.map { RecipeStepTemperature(id: $0.id, temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) }
                
                let step = RecipeStep(id: step.id, sortIndex: step.sortIndex, instructionText: step.instruction, timings: timings, temperatures: temps)
                return step
            }
            
            return RecipeStepSection(id: grp.id, sortIndex: grp.sortIndex, title: grp.title, steps: steps)
        }
                
        return Recipe(id: self.recipe.id, title: self.recipe.title, description: self.recipe.description, summarisedTip: self.recipe.summarisedSuggestion, author: self.recipe.author, sourceUrl: self.recipe.sourceUrl, image: image, timing: timing, serves: self.recipe.serves, ratingInfo: ratingInfo, dateAdded: self.recipe.dateAdded, dateModified: self.recipe.dateModified, ingredientSections: ingredientSections, stepSections: stepSections, dominantColorHex: self.recipe.dominantColorHex, homeId: self.recipe.homeId)
    }
}
