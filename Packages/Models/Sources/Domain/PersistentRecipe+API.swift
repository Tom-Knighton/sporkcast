//
//  PersistentRecipe+API.swift
//  Models
//
//  Created by Tom Knighton on 22/10/2025.
//

import API
import Foundation
import Persistence
import CryptoKit
import UIKit

public extension Recipe {
    static func entites(from dto: Recipe) async -> (DBRecipe, DBRecipeImage, [DBRecipeIngredientGroup], [DBRecipeIngredient], [DBRecipeStepGroup], [DBRecipeStep], [DBRecipeStepTiming], [DBRecipeStepTemperature], [DBRecipeRating]) {
        
        let recipeEntry: DBRecipe = .init(id: dto.id, title: dto.title, description: dto.description, author: dto.author, sourceUrl: dto.sourceUrl, dominantColorHex: dto.dominantColorHex, minutesToPrepare: dto.timing.prepTime, minutesToCook: dto.timing.cookTime, totalMins: dto.timing.totalTime, serves: dto.serves, overallRating: dto.ratingInfo?.overallRating, totalRatings: dto.ratingInfo?.totalRatings ?? 0, summarisedRating: dto.summarisedTip, summarisedSuggestion: nil, dateAdded: dto.dateAdded, dateModified: dto.dateModified, homeId: dto.homeId)
        
        let recipeImage = DBRecipeImage(recipeId: dto.id, imageSourceUrl: dto.image.imageUrl, imageData: dto.image.imageThumbnailData)
        
        let ingredientSections = dto.ingredientSections.map { $0.asDatabaseObject(for: dto.id) }
        let ingredients = dto.ingredientSections.flatMap { $0.ingredientsAsDatabaseObjects() }
        
        let stepSections = dto.stepSections.map { $0.asDatabaseObject(for: dto.id) }
        let steps = dto.stepSections.flatMap { $0.stepsAsDatabaseObjects() }
        
        var timings: [DBRecipeStepTiming] = []
        var temps: [DBRecipeStepTemperature] = []
        
        for step in dto.stepSections.flatMap(\.steps) {
            timings.append(contentsOf: step.timings.compactMap { DBRecipeStepTiming(id: $0.id, recipeStepId: step.id, timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText)})
            temps.append(contentsOf: step.temperatures.compactMap { DBRecipeStepTemperature(id: $0.id, recipeStepId: step.id, temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) })
        }
        
        let ratings = dto.ratingInfo?.ratings.compactMap { DBRecipeRating(id: $0.id, recipeId: dto.id, rating: $0.rating, comment: $0.comment)} ?? []
        
        return (recipeEntry, recipeImage, ingredientSections, ingredients, stepSections, steps, timings, temps, ratings)
        
    }
}

public extension RecipeDTO {
    static func entities(from dto: RecipeDTO, for homeId: UUID? = nil) async -> (DBRecipe, DBRecipeImage, [DBRecipeIngredientGroup], [DBRecipeIngredient], [DBRecipeStepGroup], [DBRecipeStep], [DBRecipeStepTiming], [DBRecipeStepTemperature], [DBRecipeRating]) {
        
        let recipeId = UUID()
        let now = Date()
                
        var thumbnailData: Data?
        
        do {
            if let imageUrl = dto.imageUrl, let url = URL(string: imageUrl) {
                if let download = try? await RecipeDTO.downloadImageData(from: url) {
                    let (thumb, _) = try RecipeDTO.makeThumbnailAndDetermineExt(from: download)
                    thumbnailData = thumb
                }
            }
        } catch {
            print("Error downloading image: \(error)")
        }
                
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
        
        for (index, group) in dto.stepSections.enumerated() {
            let groupId = UUID()
            
            let dbGroup = DBRecipeStepGroup(id: groupId, recipeId: recipeId, title: group.title ?? "", sortIndex: index)
            for (index, step) in (group.steps ?? []).enumerated() {
                let stepId = UUID()
                let dbStep = DBRecipeStep(id: stepId, groupId: groupId, sortIndex: index, instruction: step.step)
                
                stepTimings.append(contentsOf: step.times.compactMap { DBRecipeStepTiming(id: UUID(), recipeStepId: stepId, timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText) } )
                stepTemps.append(contentsOf: step.temperatures.compactMap { DBRecipeStepTemperature(id: UUID(), recipeStepId: stepId, temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText) } )
                
                steps.append(dbStep)
            }
            
            stepGroups.append(dbGroup)
        }
        
        return (recipe, recipeImage, ingredientGroups, ingredients, stepGroups, steps, stepTimings, stepTemps, ratings)
    }
    
    private static func downloadImageData(from url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard data.count <= 15_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        return data
    }
    
    private static func canonicalKey(from urlString: String) -> String {
        
        if let url = URL(string: urlString) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let scheme = components?.scheme?.lowercased(); let host = components?.host?.lowercased()
            components?.scheme = scheme
            components?.host = host
            
            if var path = components?.path, path.count > 1, path.hasSuffix("/") {
                path.removeLast()
                components?.path = path
            }
            
            if let queryItems = components?.queryItems, !queryItems.isEmpty {
                let sorted = queryItems.sorted { $0.name < $1.name }
                components?.queryItems = sorted
            }
            
            let normalized = components?.string ?? url.absoluteString
            
            let data = Data(normalized.utf8)
            let hash = SHA256.hash(data: data)
            
            return hash.map { String(format: "%02x", $0) }.joined()
        } else {
            let data = Data(urlString.utf8)
            let hash = SHA256.hash(data: data)
            
            return hash.map { String(format: "%02x", $0) }.joined()
        }
    }
    
    private static func makeThumbnailAndDetermineExt(from originalData: Data) throws -> (thumb: Data, ext: String) {
        guard let image = UIImage(data: originalData) else { throw CocoaError(.fileReadCorruptFile) }
        
        let maxEdge: CGFloat = 1024
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        if let jpeg = thumbnail.jpegData(compressionQuality: 0.82) {
            return (jpeg, "jpg")
        }
        guard let png = thumbnail.pngData() else { throw CocoaError(.coderInvalidValue) }
        return (png, "png")
    }
}
