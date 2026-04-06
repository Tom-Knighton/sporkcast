//
//  Recipe+Entites.swift
//  Models
//
//  Created by Tom Knighton on 22/10/2025.
//

import API
import Foundation
import Persistence
import UIKit
import Models

public extension Recipe {
    static func entites(from dto: Recipe) async -> (DBRecipe, DBRecipeImage, [DBRecipeIngredientGroup], [DBRecipeIngredient], [DBRecipeStepGroup], [DBRecipeStep], [DBRecipeStepTiming], [DBRecipeStepTemperature], [DBRecipeRating], [DBRecipeStepLinkedIngredient]) {
        
        let recipeEntry: DBRecipe = .init(id: dto.id, title: dto.title, description: dto.description, author: dto.author, sourceUrl: dto.sourceUrl, dominantColorHex: dto.dominantColorHex, minutesToPrepare: dto.timing.prepTime, minutesToCook: dto.timing.cookTime, totalMins: dto.timing.totalTime, serves: dto.serves, overallRating: dto.ratingInfo?.overallRating, totalRatings: dto.ratingInfo?.totalRatings ?? 0, summarisedRating: dto.ratingInfo?.summarisedRating, summarisedSuggestion: dto.summarisedTip, dateAdded: dto.dateAdded, dateModified: dto.dateModified, homeId: dto.homeId)
        
        let recipeImage = DBRecipeImage(recipeId: dto.id, imageSourceUrl: dto.image.imageUrl, imageData: dto.image.imageThumbnailData)
        
        let ingredientSections = dto.ingredientSections.map { $0.asDatabaseObject(for: dto.id) }
        let ingredients = dto.ingredientSections.flatMap { $0.ingredientsAsDatabaseObjects() }
        
        let stepSections = dto.stepSections.map { $0.asDatabaseObject(for: dto.id) }
        let steps = dto.stepSections.flatMap { $0.stepsAsDatabaseObjects() }
        
        var timings: [DBRecipeStepTiming] = []
        var temps: [DBRecipeStepTemperature] = []
        var linkedIngredients: [DBRecipeStepLinkedIngredient] = []
        
        for step in dto.stepSections.flatMap(\.steps) {
            timings.append(contentsOf: step.timings.compactMap { DBRecipeStepTiming(id: $0.id, recipeStepId: step.id, timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText)})
            temps.append(contentsOf: step.temperatures.compactMap { DBRecipeStepTemperature(id: $0.id, recipeStepId: step.id, temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) })
            linkedIngredients.append(contentsOf: step.linkedIngredients.compactMap { .init(id: UUID(), recipeStepId: step.id, ingredientId: $0, sortIndex: step.linkedIngredients.firstIndex(of: $0) ?? 0 )})
        }
        
        let ratings = dto.ratingInfo?.ratings.compactMap { DBRecipeRating(id: $0.id, recipeId: dto.id, rating: $0.rating, comment: $0.comment)} ?? []
        
        return (recipeEntry, recipeImage, ingredientSections, ingredients, stepSections, steps, timings, temps, ratings, linkedIngredients)
        
    }
}

public extension RecipeDTO {
    static func entities(from dto: RecipeDTO, for homeId: UUID? = nil) async -> (DBRecipe, DBRecipeImage, [DBRecipeIngredientGroup], [DBRecipeIngredient], [DBRecipeStepGroup], [DBRecipeStep], [DBRecipeStepTiming], [DBRecipeStepTemperature], [DBRecipeRating], [DBRecipeStepLinkedIngredient]) {
        
        let recipeId = UUID()
        let now = Date()
        
        let thumbnailData = await RecipeImagePersistenceSupport.resolveThumbnailData(
            imageURL: dto.imageUrl,
            sourceURL: dto.url
        )
        
        let recipe = DBRecipe(id: recipeId, title: dto.title, description: dto.description, author: dto.author, sourceUrl: dto.url, dominantColorHex: nil, minutesToPrepare: dto.minutesToPrepare, minutesToCook: dto.minutesToCook, totalMins: dto.totalMins, serves: dto.serves, overallRating: dto.ratings.overallRating, totalRatings: dto.ratings.totalRatings, summarisedRating: nil, summarisedSuggestion: nil, dateAdded: now, dateModified: now, homeId: homeId)
        
        let recipeImage = DBRecipeImage(recipeId: recipe.id, imageSourceUrl: dto.imageUrl, imageData: thumbnailData)
        
        // TODO: Support ingredient groups
        let groupId = UUID()
        let ingredientGroups = [DBRecipeIngredientGroup(id: groupId, recipeId: recipeId, title: "Ingredients", sortIndex: 0)]
        
        let ingredients = dto.ingredients.enumerated().compactMap { index, ing in
            DBRecipeIngredient(id: UUID(), ingredientGroupId: groupId, sortIndex: index, rawIngredient: ing.fullIngredient, quantity: ing.quantity, quantityText: ing.quantityText, unit: ing.unit, unitText: ing.unitText, ingredient: ing.ingredient, extra: ing.extra, emojiDescriptor: nil, owned: false)
        }
        
        var stepGroups: [DBRecipeStepGroup] = []
        var steps: [DBRecipeStep] = []
        var stepTimings: [DBRecipeStepTiming] = []
        var stepTemps: [DBRecipeStepTemperature] = []
        let ratings: [DBRecipeRating] = dto.ratings.reviews?.compactMap { DBRecipeRating(id: UUID(), recipeId: recipeId, rating: $0.rating, comment: $0.text)} ?? []
        var linkedIngredients: [DBRecipeStepLinkedIngredient] = []
        
        let ingredientMatcher = IngredientStepMatcher()
        
        for (index, group) in dto.stepSections.enumerated() {
            let groupId = UUID()
            
            let dbGroup = DBRecipeStepGroup(id: groupId, recipeId: recipeId, title: group.title ?? "", sortIndex: index)
            for (index, step) in (group.steps ?? []).enumerated() {
                let stepId = UUID()
                let dbStep = DBRecipeStep(id: stepId, groupId: groupId, sortIndex: index, instruction: step.step)
                
                stepTimings.append(contentsOf: step.times.compactMap { DBRecipeStepTiming(id: UUID(), recipeStepId: stepId, timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText) } )
                stepTemps.append(contentsOf: step.temperatures.compactMap { DBRecipeStepTemperature(id: UUID(), recipeStepId: stepId, temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) } )
                
                let matchedIngredients = ingredientMatcher.matchIngredients(for: step.step, ingredients: ingredients.compactMap { RecipeIngredient(id: $0.id, sortIndex: $0.sortIndex, ingredientText: $0.rawIngredient, ingredientPart: $0.ingredient, extraInformation: $0.extra, quantity: .init(quantity: $0.quantity, quantityText: $0.quantityText), unit: .init(unit: $0.unit, unitText: $0.unitText), emoji: $0.emojiDescriptor, owned: $0.owned)}, debug: false)
                
                linkedIngredients.append(contentsOf: matchedIngredients.ingredients.compactMap { DBRecipeStepLinkedIngredient(id: UUID(), recipeStepId: stepId, ingredientId: $0.id, sortIndex: matchedIngredients.ingredients.firstIndex(of: $0) ?? 0)})
                
                steps.append(dbStep)
            }
            
            stepGroups.append(dbGroup)
        }
        
        return (recipe, recipeImage, ingredientGroups, ingredients, stepGroups, steps, stepTimings, stepTemps, ratings, linkedIngredients)
    }
}

enum RecipeImagePersistenceSupport {
    private static let maxImageBytes = 15_000_000
    private static let maxHTMLBytes = 2_500_000
    private static let imageRequestTimeout: TimeInterval = 12
    private static let socialImageRequestTimeout: TimeInterval = 6
    private static let htmlRequestTimeout: TimeInterval = 12
    private static let browserUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func resolveThumbnailData(imageURL: String?, sourceURL: String?) async -> Data? {
        if shouldPrioritizeSourceFetch(imageURL: imageURL, sourceURL: sourceURL),
           let thumbnail = await resolveThumbnailDataFromSource(sourceURL: sourceURL) {
            return thumbnail
        }

        if let thumbnail = await resolveThumbnailDataFromImageURL(imageURL) {
            return thumbnail
        }

        guard shouldAttemptSourceFallback(imageURL: imageURL, sourceURL: sourceURL) else { return nil }
        return await resolveThumbnailDataFromSource(sourceURL: sourceURL)
    }

    static func shouldHydrateImportedImage(imageURL: String?, sourceURL: String?) -> Bool {
        isSocialSourceURL(sourceURL) || isSocialImageURL(imageURL)
    }

    private static func resolveThumbnailDataFromImageURL(_ imageURL: String?) async -> Data? {
        guard let imageURL,
              let url = URL(string: imageURL),
              let thumbnail = try? await downloadAndThumbnail(from: url) else {
            return nil
        }

        return thumbnail
    }

    private static func resolveThumbnailDataFromSource(sourceURL: String?) async -> Data? {
        guard let sourceURL,
              let source = URL(string: sourceURL),
              let previewImageURL = await fetchPreviewImageURL(from: source),
              let thumbnail = try? await downloadAndThumbnail(from: previewImageURL) else {
            return nil
        }

        return thumbnail
    }

    private static func shouldPrioritizeSourceFetch(imageURL: String?, sourceURL: String?) -> Bool {
        isSocialSourceURL(sourceURL) || isSocialImageURL(imageURL)
    }

    private static func shouldAttemptSourceFallback(imageURL: String?, sourceURL: String?) -> Bool {
        if isSocialSourceURL(sourceURL) {
            return true
        }

        guard let imageHost = host(for: imageURL) else { return false }

        return isSocialHost(imageHost)
    }

    private static func isSocialSourceURL(_ sourceURL: String?) -> Bool {
        guard let sourceHost = host(for: sourceURL) else { return false }
        return sourceHost.contains("instagram.com")
            || sourceHost.contains("tiktok.com")
    }

    private static func isSocialImageURL(_ imageURL: String?) -> Bool {
        guard let imageHost = host(for: imageURL) else { return false }
        return isSocialHost(imageHost)
    }

    private static func isSocialHost(_ host: String) -> Bool {
        host.contains("cdninstagram.com")
            || host.contains("instagram.com")
            || host.contains("fbcdn.net")
            || host.contains("tiktokcdn.com")
            || host.contains("ttwstatic.com")
            || host.contains("muscdn.com")
    }

    private static func host(for urlString: String?) -> String? {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else {
            return nil
        }

        if let host = URL(string: urlString)?.host?.lowercased() {
            return host
        }

        return URL(string: "https://\(urlString)")?.host?.lowercased()
    }

    private static func downloadAndThumbnail(from url: URL) async throws -> Data {
        let data = try await downloadImageData(from: url)
        return try makeThumbnail(from: data)
    }

    private static func downloadImageData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = isSocialHost(url.host?.lowercased() ?? "")
            ? socialImageRequestTimeout
            : imageRequestTimeout
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard data.count <= maxImageBytes else {
            throw URLError(.dataLengthExceedsMaximum)
        }

        return data
    }

    private static func fetchPreviewImageURL(from sourceURL: URL) async -> URL? {
        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = htmlRequestTimeout
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return nil
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }

        guard data.count <= maxHTMLBytes else {
            return nil
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              let rawURL = extractPreviewImageURL(from: html) else {
            return nil
        }

        let decodedURLString = decodeHTMLEntities(in: rawURL)
        guard let url = URL(string: decodedURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return url
    }

    private static func extractPreviewImageURL(from html: String) -> String? {
        let patterns = [
            #"<meta[^>]+(?:property|name)=['"](?:og:image:secure_url|og:image|twitter:image)['"][^>]+content=['"]([^'"]+)['"]"#,
            #"<meta[^>]+content=['"]([^'"]+)['"][^>]+(?:property|name)=['"](?:og:image:secure_url|og:image|twitter:image)['"]"#,
            #"<link[^>]+rel=['"]preload['"][^>]+as=['"]image['"][^>]+href=['"]([^'"]+)['"]"#,
            #"<link[^>]+href=['"]([^'"]+)['"][^>]+rel=['"]preload['"][^>]+as=['"]image['"]"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let searchRange = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: searchRange),
                  let valueRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let candidate = String(html[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }

        return nil
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&#x26;", with: "&")
    }

    private static func makeThumbnail(from originalData: Data) throws -> Data {
        guard let image = UIImage(data: originalData) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let maxEdge: CGFloat = 1024
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))

        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        if let jpeg = thumbnail.jpegData(compressionQuality: 0.82) {
            return jpeg
        }

        guard let png = thumbnail.pngData() else {
            throw CocoaError(.coderInvalidValue)
        }

        return png
    }
}

extension IngredientMatchDebug {
    func consoleDescription(index: Int) -> String {
        var lines: [String] = []
        
        lines.append("──────── Ingredient \(index + 1) ────────")
        lines.append("Name: \(ingredient.ingredientText ?? ingredient.ingredientPart ?? "<unknown>")")
        lines.append("Selected: \(selected ? "✅ YES" : "❌ NO")")
        
        if let matchedVariant {
            lines.append("Matched variant: \"\(matchedVariant)\"")
        } else {
            lines.append("Matched variant: <none>")
        }
        
        lines.append("Step index: \(index)")
        
        if let spanLength {
            lines.append("Span length: \(spanLength)")
        }
        
        if let kind {
            lines.append("Match kind: \(kind.rawValue)")
        }
        
        if let score {
            lines.append("Score: \(score)")
        }
        
        lines.append("Reason: \(reason)")
        lines.append("")
        
        return lines.joined(separator: "\n")
    }
}
