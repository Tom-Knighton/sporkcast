//
//  Recipe+API.swift
//  Models
//
//  Created by Tom Knighton on 22/10/2025.
//

import Foundation
import API

public extension SDRecipe {
    func toDomainModel() -> Recipe {
        let image = RecipeImage(imageAssetFileName: self.imageAssetFileName, imageThumbnailData: self.thumbnailData, imageUrl: self.imageUrl)
        let timing = RecipeTiming(totalTime: self.totalMins, prepTime: self.minutesToPrepare, cookTime: self.minutesToCook)
        let ratingInfo = RecipeRatingInfo(overallRating: self.overallRating, summarisedRating: self.summarisedRatings, ratings: self.ratings)
        
        let ingredientSections = [RecipeIngredientGroup(id: UUID(), title: "", sortIndex: 0, ingredients: self.ingredients?.map({ sdi in
            RecipeIngredient(id: UUID(), sortIndex: sdi.sortIndex, ingredientText: sdi.rawIngredient, ingredientPart: sdi.ingredient, extraInformation: sdi.extra, quantity: IngredientQuantity(quantity: sdi.quantity, quantityText: sdi.quantityText), unit: IngredientUnit(unit: sdi.unit, unitText: sdi.unitText), emoji: sdi.emojiDescriptor, owned: sdi.owned)
        }) ?? [])]
        
        var stepSections: [RecipeStepSection] = []
        for sdSect in self.stepSections ?? [] {
            var steps: [RecipeStep] = []
            for sdStep in sdSect.steps ?? [] {
                let timings = sdStep.timings?.map { RecipeStepTiming(id: UUID(), timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText) } ?? []
                let temps = sdStep.temperatures?.map { RecipeStepTemperature(id: UUID(), temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) } ?? []
                steps.append(.init(id: sdStep.id, sortIndex: sdStep.sortIndex, instructionText: sdStep.rawStep, timings: timings, temperatures: temps))
            }
            
            stepSections.append(.init(id: sdSect.id, sortIndex: sdSect.sortIndex, title: sdSect.title, steps: steps))
        }
        
        let recipe = Recipe(id: self.id, title: self.title, description: self.recipeDescription, author: self.author, sourceUrl: self.sourceUrl, image: image, timing: timing, serves: self.serves, ratingInfo: ratingInfo, dateAdded: self.dateAdded, dateModified: self.dateModified, ingredientSections: ingredientSections, stepSections: stepSections, dominantColorHex: self.dominantColorHex, homeId: nil)
        
        return recipe
    }
}
