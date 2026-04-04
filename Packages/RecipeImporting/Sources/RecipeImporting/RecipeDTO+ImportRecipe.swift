//
//  RecipeDTO+ImportRecipe.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import API
import Environment
import Foundation
import Models

extension RecipeDTO {
    func toImportedRecipe(homeId: UUID?) -> Recipe {
        let now = Date()

        let ingredientGroupID = UUID()
        let ingredients: [RecipeIngredient] = self.ingredients.enumerated().map { index, ingredient in
            RecipeIngredient(
                id: UUID(),
                sortIndex: index,
                ingredientText: ingredient.fullIngredient,
                ingredientPart: ingredient.ingredient,
                extraInformation: ingredient.extra,
                quantity: IngredientQuantity(quantity: ingredient.quantity, quantityText: ingredient.quantityText),
                unit: IngredientUnit(unit: ingredient.unit, unitText: ingredient.unitText),
                emoji: nil,
                owned: false
            )
        }

        let ingredientSections = [
            RecipeIngredientGroup(
                id: ingredientGroupID,
                title: "Ingredients",
                sortIndex: 0,
                ingredients: ingredients
            )
        ]

        let matcher = IngredientStepMatcher()
        let stepSections: [RecipeStepSection] = self.stepSections.enumerated().map { groupIndex, section in
            let steps = (section.steps ?? []).enumerated().map { stepIndex, step in
                let matched = matcher.matchIngredients(for: step.step, ingredients: ingredients)
                return RecipeStep(
                    id: UUID(),
                    sortIndex: stepIndex,
                    instructionText: step.step,
                    timings: step.times.map {
                        RecipeStepTiming(
                            id: UUID(),
                            timeInSeconds: $0.timeInSeconds,
                            timeText: $0.timeText,
                            timeUnitText: $0.timeUnitText
                        )
                    },
                    temperatures: step.temperatures.map {
                        RecipeStepTemperature(
                            id: UUID(),
                            temperature: $0.temperature,
                            temperatureText: $0.temperatureText,
                            temperatureUnitText: $0.temperatureUnitText
                        )
                    },
                    linkedIngredients: matched.map(\.id)
                )
            }

            return RecipeStepSection(
                id: UUID(),
                sortIndex: groupIndex,
                title: section.title ?? "Method",
                steps: steps
            )
        }

        let ratings: [RecipeRating] = self.ratings.reviews?.map {
            RecipeRating(id: UUID(), rating: $0.rating, comment: $0.text)
        } ?? []

        let ratingInfo = RecipeRatingInfo(
            overallRating: self.ratings.overallRating,
            totalRatings: self.ratings.totalRatings,
            summarisedRating: nil,
            ratings: ratings
        )

        return Recipe(
            id: UUID(),
            title: title,
            description: description,
            summarisedTip: nil,
            author: author,
            sourceUrl: SyntheticSourceURL.isExternalWebURL(url) ? url : SyntheticSourceURL.make(mode: .web, vendor: .web, seed: title),
            image: RecipeImage(imageThumbnailData: nil, imageUrl: imageUrl),
            timing: RecipeTiming(totalTime: totalMins, prepTime: minutesToPrepare, cookTime: minutesToCook),
            serves: serves,
            ratingInfo: ratingInfo,
            dateAdded: now,
            dateModified: now,
            ingredientSections: ingredientSections,
            stepSections: stepSections,
            dominantColorHex: nil,
            homeId: homeId
        )
    }
}
