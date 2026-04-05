//
//  RecipeImportCoordinator.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import API
import Environment
import Foundation
import Models

public actor RecipeImportCoordinator: RecipeImporting {

    private let client: any NetworkClient
    private let fileParser = RecipeImportFileParser()
    private let normalizer = RecipeImportNormalizer()

    public init(client: any NetworkClient) {
        self.client = client
    }

    public func prepareImport(from source: RecipeImportSource, homeId: UUID?) async throws -> RecipeImportResult {
        let parsedRecords: [ParsedImportRecord]

        switch source {
        case .webURL(let url):
            parsedRecords = try await parseFromWeb(url: url, homeId: homeId)
        case .fileURL(let url, let vendorHint):
            parsedRecords = try fileParser.parse(fileURL: url, vendorHint: vendorHint)
        case .markdownText(let text):
            let records = MarkdownRecipeParser().parse(text)
            parsedRecords = records.map {
                ParsedImportRecord(
                    record: $0,
                    provenance: RecipeImportProvenance(mode: .markdown, vendor: .markdown, sourceHint: "markdown-paste"),
                    rawText: text
                )
            }
        case .webSelection(let text, let sourceURL):
            let records = MarkdownRecipeParser().parse(text)
            parsedRecords = records.map {
                ParsedImportRecord(
                    record: $0,
                    provenance: RecipeImportProvenance(mode: .webSelection, vendor: .unknown, sourceHint: sourceURL?.absoluteString),
                    rawText: text
                )
            }
        case .ocrText(let text):
            let records = MarkdownRecipeParser().parse(text)
            parsedRecords = records.map {
                ParsedImportRecord(
                    record: $0,
                    provenance: RecipeImportProvenance(mode: .ocr, vendor: .unknown, sourceHint: "ocr"),
                    rawText: text
                )
            }
        }

        guard !parsedRecords.isEmpty else {
            throw RecipeImportError.noRecipesDetected
        }

        var candidates: [RecipeImportCandidate] = []

        for parsed in parsedRecords {
            var recipe = normalizer.normalize(record: parsed.record, provenance: parsed.provenance, homeId: homeId)
            var quality = ImportQuality.evaluate(recipe: recipe)
            var usedFallback = false

            if quality.shouldFallbackToAPI,
               let fallback = try await fallbackToAPI(text: parsed.rawText, sourceHint: parsed.provenance.sourceHint, homeId: homeId) {
                recipe = fallback
                quality = ImportQuality.evaluate(recipe: recipe)
                usedFallback = true
            }

            candidates.append(
                RecipeImportCandidate(
                    recipe: recipe,
                    provenance: parsed.provenance,
                    quality: quality,
                    usedAPIFallback: usedFallback,
                    rawTextForFallback: parsed.rawText
                )
            )
        }

        return RecipeImportResult(candidates: candidates, duplicateMatches: [:])
    }

    public nonisolated func detectDuplicates(for candidates: [RecipeImportCandidate], existing: [Recipe]) -> [UUID: DuplicateMatch] {
        var map: [UUID: DuplicateMatch] = [:]

        for candidate in candidates {
            let scored = existing.compactMap { existingRecipe -> (Recipe, Double, String)? in
                let similarity = candidate.recipe.duplicateSimilarity(with: existingRecipe)
                guard similarity.score >= 0.65 else { return nil }
                return (existingRecipe, similarity.score, similarity.reason)
            }
            .sorted { $0.1 > $1.1 }

            if let best = scored.first {
                map[candidate.id] = DuplicateMatch(
                    candidateID: candidate.id,
                    existingRecipeID: best.0.id,
                    existingTitle: best.0.title,
                    confidence: best.1,
                    reason: best.2
                )
            }
        }

        return map
    }

    public func persist(
        candidates: [RecipeImportCandidate],
        decisions: [UUID: DuplicateResolutionDecision],
        repository: RecipesRepository
    ) async throws {
        var recipesToInsert: [Recipe] = []
        var replacements: [(existingRecipeId: UUID, recipe: Recipe)] = []

        for candidate in candidates {
            let decision = decisions[candidate.id]

            switch decision?.resolution ?? .keepBoth {
            case .keepBoth:
                recipesToInsert.append(candidate.recipe)
            case .skip:
                continue
            case .replace:
                if let existingId = decision?.existingRecipeID {
                    replacements.append((existingRecipeId: existingId, recipe: candidate.recipe))
                } else {
                    recipesToInsert.append(candidate.recipe)
                }
            }
        }

        if !recipesToInsert.isEmpty {
            try await repository.saveImportedRecipes(recipesToInsert)
        }

        for replacement in replacements {
            try await repository.replaceImportedRecipe(existingRecipeId: replacement.existingRecipeId, with: replacement.recipe)
        }
    }

    private func parseFromWeb(url: URL, homeId: UUID?) async throws -> [ParsedImportRecord] {
        let recipeDTO: RecipeDTO? = try await client.post(Recipes.uploadFromUrl(url: url.absoluteString))
        guard let recipeDTO else {
            throw RecipeImportError.apiReturnedNoRecipe
        }

        let recipe = recipeDTO.toImportedRecipe(homeId: homeId)
        let rawLines = [recipe.title]
            + recipe.ingredientSections.flatMap { $0.ingredients.map(\.ingredientText) }
            + recipe.stepSections.flatMap { $0.steps.map(\.instructionText) }

        let record = ImportedRecipeRecord(
            title: recipe.title,
            description: recipe.description,
            author: recipe.author,
            sourceURL: recipe.sourceUrl,
            imageURL: recipe.image.imageUrl,
            imageData: recipe.image.imageThumbnailData,
            serves: recipe.serves,
            prepMinutes: recipe.timing.prepTime,
            cookMinutes: recipe.timing.cookTime,
            totalMinutes: recipe.timing.totalTime,
            overallRating: recipe.ratingInfo?.overallRating,
            totalRatings: recipe.ratingInfo?.totalRatings,
            summarisedRating: recipe.ratingInfo?.summarisedRating,
            ratings: recipe.ratingInfo?.ratings.map {
                ImportedRecipeRating(id: $0.id, rating: $0.rating, comment: $0.comment)
            } ?? [],
            ingredientSections: recipe.ingredientSections.map {
                ImportedIngredientSection(title: $0.title, ingredients: $0.ingredients.map(\.ingredientText))
            },
            stepSections: recipe.stepSections.map {
                ImportedStepSection(title: $0.title, steps: $0.steps.map(\.instructionText))
            }
        )

        return [
            ParsedImportRecord(
                record: record,
                provenance: RecipeImportProvenance(mode: .web, vendor: .web, sourceHint: url.absoluteString),
                rawText: rawLines.joined(separator: "\n")
            )
        ]
    }

    private func fallbackToAPI(text: String, sourceHint: String?, homeId: UUID?) async throws -> Recipe? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            let dto: RecipeDTO? = try await client.post(Recipes.uploadFromText(text: trimmed, sourceHint: sourceHint))
            guard let dto else { return nil }
            return dto.toImportedRecipe(homeId: homeId)
        } catch {
            return nil
        }
    }
}
