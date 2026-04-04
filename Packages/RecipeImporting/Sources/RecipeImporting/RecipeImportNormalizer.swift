//
//  RecipeImportNormalizer.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Environment
import Foundation
import Models

struct RecipeImportNormalizer {

    func normalize(
        record: ImportedRecipeRecord,
        provenance: RecipeImportProvenance,
        homeId: UUID?
    ) -> Recipe {
        let recipeID = UUID()
        let now = Date()

        let ingredientSections = normalizeIngredientSections(record.ingredientSections)
        var stepSections = normalizeStepSections(record.stepSections)

        let allIngredients = ingredientSections.flatMap(\.ingredients)
        let matcher = IngredientStepMatcher()

        for sectionIndex in stepSections.indices {
            for stepIndex in stepSections[sectionIndex].steps.indices {
                let step = stepSections[sectionIndex].steps[stepIndex]
                let matched = matcher.matchIngredients(for: step.instructionText, ingredients: allIngredients)
                stepSections[sectionIndex].steps[stepIndex].linkedIngredients = matched.map(\.id)
            }
        }

        let resolvedSource: String
        if let existing = record.sourceURL, SyntheticSourceURL.isExternalWebURL(existing) {
            resolvedSource = existing
        } else {
            resolvedSource = SyntheticSourceURL.make(
                mode: provenance.mode,
                vendor: provenance.vendor,
                seed: "\(record.title)|\(record.description ?? "")|\(provenance.sourceHint ?? "")"
            )
        }

        return Recipe(
            id: recipeID,
            title: record.title,
            description: record.description,
            summarisedTip: nil,
            author: record.author,
            sourceUrl: resolvedSource,
            image: RecipeImage(imageThumbnailData: record.imageData, imageUrl: record.imageURL),
            timing: RecipeTiming(totalTime: record.totalMinutes, prepTime: record.prepMinutes, cookTime: record.cookMinutes),
            serves: record.serves,
            ratingInfo: nil,
            dateAdded: now,
            dateModified: now,
            ingredientSections: ingredientSections,
            stepSections: stepSections,
            dominantColorHex: nil,
            homeId: homeId
        )
    }

    private func normalizeIngredientSections(_ sections: [ImportedIngredientSection]) -> [RecipeIngredientGroup] {
        let safeSections = sections.isEmpty ? [ImportedIngredientSection(title: "Ingredients", ingredients: [])] : sections

        return safeSections.enumerated().map { sectionIndex, section in
            let ingredients = section.ingredients.enumerated().map { ingredientIndex, rawLine in
                let parsed = try? parseIngredient(rawLine, "en", includeExtra: true, includeAlternativeUnits: false, fallbackLanguage: "en")

                return RecipeIngredient(
                    id: UUID(),
                    sortIndex: ingredientIndex,
                    ingredientText: rawLine,
                    ingredientPart: parsed?.ingredient,
                    extraInformation: parsed?.extra,
                    quantity: IngredientQuantity(quantity: parsed?.quantity, quantityText: parsed?.quantityText),
                    unit: IngredientUnit(unit: parsed?.unit, unitText: parsed?.unitText),
                    emoji: nil,
                    owned: false
                )
            }

            return RecipeIngredientGroup(
                id: UUID(),
                title: section.title.isEmpty ? "Ingredients" : section.title,
                sortIndex: sectionIndex,
                ingredients: ingredients
            )
        }
    }

    private func normalizeStepSections(_ sections: [ImportedStepSection]) -> [RecipeStepSection] {
        let safeSections = sections.isEmpty ? [ImportedStepSection(title: "Method", steps: [])] : sections

        return safeSections.enumerated().map { sectionIndex, section in
            let steps = section.steps.enumerated().map { stepIndex, rawStep in
                let parsed = try? parseInstruction(rawStep, "en", includeAlternativeTemperatureUnit: false, fallbackLanguage: "en")

                return RecipeStep(
                    id: UUID(),
                    sortIndex: stepIndex,
                    instructionText: rawStep,
                    timings: parsed?.timeItems.map {
                        RecipeStepTiming(
                            id: UUID(),
                            timeInSeconds: Double($0.timeInSeconds),
                            timeText: $0.timeText,
                            timeUnitText: $0.timeUnitText
                        )
                    } ?? [],
                    temperatures: {
                        guard let parsed, parsed.temperature > 0 else { return [] }
                        return [
                            RecipeStepTemperature(
                                id: UUID(),
                                temperature: parsed.temperature,
                                temperatureText: parsed.temperatureText,
                                temperatureUnitText: parsed.temperatureUnitText
                            )
                        ]
                    }(),
                    linkedIngredients: []
                )
            }

            return RecipeStepSection(
                id: UUID(),
                sortIndex: sectionIndex,
                title: section.title.isEmpty ? "Method" : section.title,
                steps: steps
            )
        }
    }
}
