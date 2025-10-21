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
public final class SDRecipe {
    
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
    
    @Relationship(deleteRule: .cascade, inverse: \SDRecipeIngredient.recipe) public var ingredients: [SDRecipeIngredient]?
    @Relationship(deleteRule: .cascade, inverse: \SDRecipeStepSection.recipe) public var stepSections: [SDRecipeStepSection]?
    
    public init(id: UUID = .init(), canonicalKey: String, title: String, recipeDescription: String? = nil, author: String? = nil, sourceUrl: String, imageAssetFileName: String? = nil, minutesToPrepare: Double? = nil, minutesToCook: Double? = nil, totalMins: Double? = nil, serves: String? = nil, overallRating: Double? = nil, summarisedRatings: String? = nil, summarisedSuggestion: String? = nil, ratings: [String], dateAdded: Date, dateModified: Date, ingredients: [SDRecipeIngredient], stepSections: [SDRecipeStepSection]) {
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
public final class SDRecipeIngredient {
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
    
    @Relationship var recipe: SDRecipe?
    
    public init(rawIngredient: String, sortIndex: Int, quantity: Double? = nil, quantityText: String? = nil, minQuantity: Double? = nil, maxQuantity: Double? = nil, unit: String? = nil, unitText: String? = nil, ingredient: String? = nil, extra: String? = nil, emojiDescriptor: String? = nil, owned: Bool, recipe: SDRecipe? = nil) {
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
public final class SDRecipeStepSection {
    public var id: UUID = UUID()
    public var title: String = ""
    public var sortIndex: Int = 0
    
    @Relationship public var recipe: SDRecipe?
    @Relationship(deleteRule: .cascade, inverse: \SDRecipeStep.recipeStepSection) public var steps: [SDRecipeStep]?
    
    public init(title: String, sortIndex: Int, recipe: SDRecipe? = nil, steps: [SDRecipeStep]) {
        self.id = UUID()
        self.title = title
        self.sortIndex = sortIndex
        self.recipe = recipe
        self.steps = steps
    }
}

@Model
public final class SDRecipeStep: @unchecked Sendable {
    
    public var id: UUID = UUID()
    public var rawStep: String = ""
    public var sortIndex: Int = 0
    
    @Relationship(deleteRule: .cascade, inverse: \SDRecipeStepTiming.recipeStep) public var timings: [SDRecipeStepTiming]?
    @Relationship(deleteRule: .cascade, inverse: \SDRecipeStepTemp.recipeStep) public var temperatures: [SDRecipeStepTemp]?
    @Relationship var recipeStepSection: SDRecipeStepSection?
    
    public init(rawStep: String, sortIndex: Int, timings: [SDRecipeStepTiming], temperatures: [SDRecipeStepTemp], recipeStepSection: SDRecipeStepSection? = nil) {
        self.id = UUID()
        self.rawStep = rawStep
        self.sortIndex = sortIndex
        self.timings = timings
        self.temperatures = temperatures
        self.recipeStepSection = recipeStepSection
    }
}

@Model
public final class SDRecipeStepTiming {
    public var timeInSeconds: Double = 0
    public var timeText: String = ""
    public var timeUnitText: String = ""
    
    @Relationship var recipeStep: SDRecipeStep?
    
    public init(timeInSeconds: Double, timeText: String, timeUnitText: String, recipeStep: SDRecipeStep? = nil) {
        self.timeInSeconds = timeInSeconds
        self.timeText = timeText
        self.timeUnitText = timeUnitText
        self.recipeStep = recipeStep
    }
}


@Model
public final class SDRecipeStepTemp {
    public var temperature: Double = 0
    public var temperatureText: String = ""
    public var temperatureUnitText: String = ""
    
    @Relationship var recipeStep: SDRecipeStep?
    
    public init(temperature: Double, temperatureText: String, temperatureUnitText: String, recipeStep: SDRecipeStep? = nil) {
        self.temperature = temperature
        self.temperatureText = temperatureText
        self.temperatureUnitText = temperatureUnitText
        self.recipeStep = recipeStep
    }
}


public extension SDRecipe {
    
    convenience init(from dto: RecipeDTO) async {
        
        let key = SDRecipe.canonicalKey(from: dto.url)
        
        var thumbnailData: Data?
        var fileName: String?
        
        do {
            if let imageUrl = dto.imageUrl, let url = URL(string: imageUrl) {
                if let download = try? await SDRecipe.downloadImageData(from: url) {
                    let (thumb, ext) = try SDRecipe.makeThumbnailAndDetermineExt(from: download)
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
        
        var ingredients: [SDRecipeIngredient] = []
        for i in 0..<dto.ingredients.count {
            let dtoIng = dto.ingredients[i]
            let newIng = SDRecipeIngredient(rawIngredient: dtoIng.fullIngredient, sortIndex: i, quantity: dtoIng.quantity, quantityText: dtoIng.quantityText, minQuantity: dtoIng.minQuantity, maxQuantity: dtoIng.maxQuantity, unit: dtoIng.unit, unitText: dtoIng.unitText, ingredient: dtoIng.ingredient, extra: dtoIng.extra, emojiDescriptor: nil, owned: false)
            ingredients.append(newIng)
        }
        self.ingredients = ingredients
        
        var stepSections: [SDRecipeStepSection] = []
        for i in 0..<dto.stepSections.count {
            let dtoSect = dto.stepSections[i]
            
            var steps: [SDRecipeStep] = []
            if let dtoSteps = dtoSect.steps {
                for j in 0..<dtoSteps.count {
                    let dtoStep = dtoSteps[j]
                    let newStep = SDRecipeStep(rawStep: dtoStep.step, sortIndex: j, timings: dtoStep.times.compactMap { SDRecipeStepTiming(timeInSeconds: $0.timeInSeconds, timeText: $0.timeText, timeUnitText: $0.timeUnitText)}, temperatures: dtoStep.temperatures.compactMap { SDRecipeStepTemp(temperature: $0.temperature, temperatureText: $0.temperatureText, temperatureUnitText: $0.temperatureUnitText)})
                    steps.append(newStep)
                }
            }
            
            let newSect = SDRecipeStepSection(title: dtoSect.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", sortIndex: i, steps: steps)
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


extension SDRecipe {
    public func toDomainModel() -> Recipe {
        
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
        
        let recipe = Recipe(id: self.id, title: self.title, description: self.recipeDescription, author: self.author, sourceUrl: self.sourceUrl, image: image, timing: timing, serves: self.serves, ratingInfo: ratingInfo, dateAdded: self.dateAdded, dateModified: self.dateModified, ingredientSections: ingredientSections, stepSections: stepSections, dominantColorHex: self.dominantColorHex)
        
        return recipe
    }
}
