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
    private let sharedPageReader: @Sendable (URL) -> ImportedRecipeRecord?

    public init(client: any NetworkClient) {
        self.client = client
        self.sharedPageReader = { SharedRecipePageReader.takeRecipe(for: $0) }
    }

    init(client: any NetworkClient, sharedPageReader: @escaping @Sendable (URL) -> ImportedRecipeRecord?) {
        self.client = client
        self.sharedPageReader = sharedPageReader
    }

    public func prepareImport(from source: RecipeImportSource, homeId: UUID?) async throws -> RecipeImportResult {
        let started = ProcessInfo.processInfo.systemUptime
        defer { RecipeImportPerformance.record("prepare-total", since: started) }
        let parsedRecords: [ParsedImportRecord]

        switch source {
        case .webURL(let url):
            if SocialRecipeSource.isSupported(url) {
                parsedRecords = try await parseFromSocialWeb(url: url, homeId: homeId)
            } else {
                parsedRecords = try await parseFromWeb(url: url, homeId: homeId)
            }
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
            let normalizeStarted = ProcessInfo.processInfo.systemUptime
            var recipe = parsed.enrichedRecipe ?? normalizer.normalize(record: parsed.record, provenance: parsed.provenance, homeId: homeId)
            RecipeImportPerformance.record("normalize", since: normalizeStarted)
            var quality = ImportQuality.evaluate(recipe: recipe)
            var usedFallback = false

            if parsed.enrichedRecipe == nil, quality.shouldFallbackToAPI,
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
        detectDuplicates(for: candidates, existing: existing.map(RecipeDuplicateSummary.init(recipe:)))
    }

    public nonisolated func detectDuplicates(for candidates: [RecipeImportCandidate], existing: [RecipeDuplicateSummary]) -> [UUID: DuplicateMatch] {
        let started = ProcessInfo.processInfo.systemUptime
        defer { RecipeImportPerformance.record("duplicate-match", since: started) }
        var map: [UUID: DuplicateMatch] = [:]
        for candidate in candidates {
            let summary = RecipeDuplicateSummary(recipe: candidate.recipe)
            if let source = RecipeDuplicateSummary.sourceKey(summary.sourceURL),
               let exact = existing.first(where: { RecipeDuplicateSummary.sourceKey($0.sourceURL) == source }) {
                map[candidate.id] = DuplicateMatch(candidateID: candidate.id, existingRecipeID: exact.id,
                    existingTitle: exact.title, confidence: 1, reason: "Matching source URL")
                continue
            }
            var best: (RecipeDuplicateSummary, Double, String)?
            for recipe in existing {
                let similarity = summary.duplicateSimilarity(with: recipe)
                guard similarity.score >= 0.65, similarity.score > (best?.1 ?? 0) else { continue }
                best = (recipe, similarity.score, similarity.reason)
                if similarity.score == 1 { break }
            }
            if let best {
                map[candidate.id] = DuplicateMatch(candidateID: candidate.id, existingRecipeID: best.0.id,
                    existingTitle: best.0.title, confidence: best.1, reason: best.2)
            }
        }
        return map
    }

    public func persist(
        candidates: [RecipeImportCandidate],
        decisions: [UUID: DuplicateResolutionDecision],
        repository: RecipesRepository
    ) async throws {
        let started = ProcessInfo.processInfo.systemUptime
        defer { RecipeImportPerformance.record("persist", since: started) }
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
        let localStarted = ProcessInfo.processInfo.systemUptime
        if let record = sharedPageReader(url) {
            let provenance = RecipeImportProvenance(mode: .web, vendor: .web, sourceHint: url.absoluteString)
            let recipe = normalizer.normalize(record: record, provenance: provenance, homeId: homeId)
            RecipeImportPerformance.record("safari-metadata", since: localStarted)
            return [ParsedImportRecord(record: record, provenance: provenance, enrichedRecipe: recipe, rawText: record.title)]
        }
        let recipeDTO: RecipeDTO?
        do {
            let networkStarted = ProcessInfo.processInfo.systemUptime
            defer { RecipeImportPerformance.record("api-request", since: networkStarted) }
            recipeDTO = try await client.post(Recipes.uploadFromUrl(url: url.absoluteString))
        }
        guard let recipeDTO else {
            throw RecipeImportError.apiReturnedNoRecipe
        }

        return parsedRecords(from: recipeDTO, homeId: homeId, sourceURL: url)
    }

    private func parseFromSocialWeb(url: URL, homeId: UUID?) async throws -> [ParsedImportRecord] {
        do {
            return try await parseFromWeb(url: url, homeId: homeId)
        } catch {
            try Task.checkCancellation()
            return try await parseFromSocialPage(url: url, homeId: homeId)
        }
    }

    private func parseFromSocialPage(url: URL, homeId: UUID?) async throws -> [ParsedImportRecord] {
        let html = try await fetchSocialPageHTML(from: url)
        guard let content = SocialRecipePageExtractor.extractRecipeContent(from: html) else {
            throw RecipeImportError.noRecipesDetected
        }
        let recipeText = content.recipeText

        let records = MarkdownRecipeParser().parse(recipeText)
        if !records.isEmpty {
            return records.map {
                var record = $0
                record.sourceURL = url.absoluteString
                record.imageURL = content.imageURL

                return ParsedImportRecord(
                    record: record,
                    provenance: RecipeImportProvenance(mode: .web, vendor: .web, sourceHint: url.absoluteString),
                    rawText: recipeText
                )
            }
        }

        let recipeDTO: RecipeDTO? = try await client.post(Recipes.uploadFromText(text: recipeText, sourceHint: url.absoluteString))
        guard let recipeDTO else {
            throw RecipeImportError.apiReturnedNoRecipe
        }

        return parsedRecords(from: recipeDTO, homeId: homeId, sourceURL: url).map {
            var parsed = $0
            parsed.record.sourceURL = url.absoluteString
            parsed.record.imageURL = parsed.record.imageURL ?? content.imageURL
            return parsed
        }
    }

    private func fetchSocialPageHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw RecipeImportError.unreadableFile
        }

        return html
    }

    private func parsedRecords(from recipeDTO: RecipeDTO, homeId: UUID?, sourceURL: URL) -> [ParsedImportRecord] {
        let started = ProcessInfo.processInfo.systemUptime
        defer { RecipeImportPerformance.record("api-map", since: started) }
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
                provenance: RecipeImportProvenance(mode: .web, vendor: .web, sourceHint: sourceURL.absoluteString),
                enrichedRecipe: recipe,
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
            try Task.checkCancellation()
            return nil
        }
    }
}
