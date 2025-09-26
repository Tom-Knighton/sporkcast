//
//  Recipe.swift
//  API
//
//  Created by Tom Knighton on 20/09/2025.
//

import Foundation
import SwiftData
import CryptoKit
import UIKit
import SwiftUI

@Model
public final class Recipe {
    
    public var id: UUID = UUID()
    public var canonicalKey: String = ""
    
    public var title: String = ""
    public var recipeDescription: String?
    public var author: String?
    public var sourceUrl: String = ""
    public var imageAssetFileName: String?
    @Attribute(.externalStorage)
    public var thumbnailData: Data?
    public var imageUrl: String?
    public var dominantColorHex: String?
    
    public var minutesToPrepare: Double?
    public var minutesToCook: Double?
    public var totalMins: Double?
    public var serves: String?
    
    public var overallRating: Double?
    public var summarisedRatings: String?
    public var summarisedSuggestion: String?
    public var ratings: [String] = []
    
    public var dateAdded: Date = Date()
    public var dateModified: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe) public var ingredients: [RecipeIngredient]?
    @Relationship(deleteRule: .cascade, inverse: \RecipeStepSection.recipe) public var stepSections: [RecipeStepSection]?
    
    public init(id: UUID = .init(), canonicalKey: String, title: String, recipeDescription: String? = nil, author: String? = nil, sourceUrl: String, imageAssetFileName: String? = nil, minutesToPrepare: Double? = nil, minutesToCook: Double? = nil, totalMins: Double? = nil, serves: String? = nil, overallRating: Double? = nil, summarisedRatings: String? = nil, summarisedSuggestion: String? = nil, ratings: [String], dateAdded: Date, dateModified: Date, ingredients: [RecipeIngredient], stepSections: [RecipeStepSection]) {
        self.id = id
        self.canonicalKey = canonicalKey
        self.title = title
        self.recipeDescription = recipeDescription
        self.author = author
        self.sourceUrl = sourceUrl
        self.imageAssetFileName = imageAssetFileName
        self.minutesToPrepare = minutesToPrepare
        self.minutesToCook = minutesToCook
        self.totalMins = totalMins
        self.serves = serves
        self.overallRating = overallRating
        self.summarisedRatings = summarisedRatings
        self.summarisedSuggestion = summarisedSuggestion
        self.ratings = ratings
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.ingredients = ingredients
        self.stepSections = stepSections
    }
}

@Model
public final class RecipeIngredient {
    public var rawIngredient: String = ""
    public var sortIndex: Int = 0
    public var quantity: Double?
    public var quantityText: String?
    public var minQuantity: Double?
    public var maxQuantity: Double?
    public var unit: String?
    public var unitText: String?
    public var ingredient: String?
    public var extra: String?
    public var emojiDescriptor: String?
    public var owned: Bool = false
    
    @Relationship var recipe: Recipe?
    
    public init(rawIngredient: String, sortIndex: Int, quantity: Double? = nil, quantityText: String? = nil, minQuantity: Double? = nil, maxQuantity: Double? = nil, unit: String? = nil, unitText: String? = nil, ingredient: String? = nil, extra: String? = nil, emojiDescriptor: String? = nil, owned: Bool, recipe: Recipe? = nil) {
        self.rawIngredient = rawIngredient
        self.sortIndex = sortIndex
        self.quantity = quantity
        self.quantityText = quantityText
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
        self.unit = unit
        self.unitText = unitText
        self.ingredient = ingredient
        self.extra = extra
        self.emojiDescriptor = emojiDescriptor
        self.owned = owned
        self.recipe = recipe
    }
}

@Model
public final class RecipeStepSection {
    public var title: String = ""
    public var sortIndex: Int = 0
    
    @Relationship public var recipe: Recipe?
    @Relationship(deleteRule: .cascade, inverse: \RecipeStep.recipeStepSection) public var steps: [RecipeStep]?
    
    public init(title: String, sortIndex: Int, recipe: Recipe? = nil, steps: [RecipeStep]) {
        self.title = title
        self.sortIndex = sortIndex
        self.recipe = recipe
        self.steps = steps
    }
}

@Model
public final class RecipeStep {
    
    public var rawStep: String = ""
    public var sortIndex: Int = 0
    
    @Relationship(deleteRule: .cascade, inverse: \RecipeStepTiming.recipeStep) public var timings: [RecipeStepTiming]?
    @Relationship(deleteRule: .cascade, inverse: \RecipeStepTemp.recipeStep) public var temperatures: [RecipeStepTemp]?
    @Relationship var recipeStepSection: RecipeStepSection?
    
    public init(rawStep: String, sortIndex: Int, timings: [RecipeStepTiming], temperatures: [RecipeStepTemp], recipeStepSection: RecipeStepSection? = nil) {
        self.rawStep = rawStep
        self.sortIndex = sortIndex
        self.timings = timings
        self.temperatures = temperatures
        self.recipeStepSection = recipeStepSection
    }
}

@Model
public final class RecipeStepTiming {
    public var timeInSeconds: Double = 0
    public var timeText: String = ""
    public var timeUnitText: String = ""
    
    @Relationship var recipeStep: RecipeStep?
    
    public init(timeInSeconds: Double, timeText: String, timeUnitText: String, recipeStep: RecipeStep? = nil) {
        self.timeInSeconds = timeInSeconds
        self.timeText = timeText
        self.timeUnitText = timeUnitText
        self.recipeStep = recipeStep
    }
}


@Model
public final class RecipeStepTemp {
    public var temperature: Double = 0
    public var temperatureText: String = ""
    public var temperatureUnitText: String = ""
    
    @Relationship var recipeStep: RecipeStep?
    
    public init(temperature: Double, temperatureText: String, temperatureUnitText: String, recipeStep: RecipeStep? = nil) {
        self.temperature = temperature
        self.temperatureText = temperatureText
        self.temperatureUnitText = temperatureUnitText
        self.recipeStep = recipeStep
    }
}


public extension Recipe {
    
    convenience init(from dto: RecipeDTO) async {
        
        let key = Recipe.canonicalKey(from: dto.url)
        
        var thumbnailData: Data?
        var fileName: String?
        
        do {
            if let imageUrl = dto.imageUrl, let url = URL(string: imageUrl) {
                if let download = try? await Recipe.downloadImageData(from: url) {
                    let (thumb, ext) = try Recipe.makeThumbnailAndDetermineExt(from: download)
                    let fileURL = try ImageStore.fileURL(forKey: key, ext: ext)
                    try download.write(to: fileURL, options: .atomic)
                    fileName = fileURL.lastPathComponent
                    thumbnailData = thumb
                }
            }
        } catch {
            print("Error downloading image: \(error)")
        }
       
        
        self.init(canonicalKey: key, title: dto.title, sourceUrl: dto.url, imageAssetFileName: fileName, ratings: [], dateAdded: Date(), dateModified: Date(), ingredients: [], stepSections: [])
        self.thumbnailData = thumbnailData
        self.title = dto.title
        self.recipeDescription = dto.description
        self.author = dto.author
        self.sourceUrl = dto.url
        self.imageUrl = dto.imageUrl
        
        self.minutesToPrepare = dto.minutesToPrepare
        self.minutesToCook = dto.minutesToCook
        self.totalMins = dto.totalMins
        self.serves = dto.serves
        
        self.overallRating = dto.ratings.overallRating
        self.ratings = dto.ratings.reviews?.map(\.text) ?? []
        
        var ingredients: [RecipeIngredient] = []
        for i in 0..<dto.ingredients.count {
            let dtoIng = dto.ingredients[i]
            let newIng = RecipeIngredient(rawIngredient: dtoIng.fullIngredient, sortIndex: i, quantity: dtoIng.quantity, quantityText: dtoIng.quantityText, minQuantity: dtoIng.minQuantity, maxQuantity: dtoIng.maxQuantity, unit: dtoIng.unit, unitText: dtoIng.unitText, ingredient: dtoIng.ingredient, extra: dtoIng.extra, emojiDescriptor: nil, owned: false)
            ingredients.append(newIng)
        }
        self.ingredients = ingredients
        
        var stepSections: [RecipeStepSection] = []
        for i in 0..<dto.stepSections.count {
            let dtoSect = dto.stepSections[i]
            
            var steps: [RecipeStep] = []
            if let dtoSteps = dtoSect.steps {
                for j in 0..<dtoSteps.count {
                    let dtoStep = dtoSteps[j]
                    let newStep = RecipeStep(rawStep: dtoStep.step, sortIndex: j, timings: dtoStep.times.compactMap { RecipeStepTiming(timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText)}, temperatures: dtoStep.temperatures.compactMap { RecipeStepTemp(temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText)})
                    steps.append(newStep)
                }
            }
            
            let newSect = RecipeStepSection(title: dtoSect.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", sortIndex: i, steps: steps)
            stepSections.append(newSect)
        }
        self.stepSections = stepSections
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


