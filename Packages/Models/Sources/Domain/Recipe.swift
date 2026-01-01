//
//  Recipe.swift
//  API
//
//  Created by Tom Knighton on 21/10/2025.
//

import Foundation
import API

public struct Recipe: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    
    /// The title of the recipe
    public let title: String
    
    /// An optional brief description of the recipe
    public let description: String?
    
    /// The original creator/poster of the recipe, occasionally will be a friendly version of the site
    public let author: String?
    
    /// The url the recipe was originally imported from - and where users should be directed to if they wish to view the original recipe
    public let sourceUrl: String
    
    /// Details of the image to display for the recipe
    public let image: RecipeImage
    
    /// How long the recipe takes to cook/prepare
    public let timing: RecipeTiming
    
    /// If present, what the recipe 'serves' i.e. '6' (for 6 people). Occasionally recipes will format this as '1 loaf' etc.
    public let serves: String?
    
    /// Details on ratings/reviews
    public let ratingInfo: RecipeRatingInfo?
    
    /// The date the user added/imported this recipe
    public let dateAdded: Date
    
    /// The date the user last modified this recipe, i.e. by editing it manually, reimporting...
    public let dateModified: Date
    
    /// Groups of ingredients in the recipe
    public let ingredientSections: [RecipeIngredientGroup]
    
    /// Sections of steps in the recipe
    public let stepSections: [RecipeStepSection]

    /// The primary colour associated with the recipe
    public var dominantColorHex: String?
    
    /// The id of the home this recipe is a part of, if any
    public var homeId: UUID?

    
    public init(id: UUID, title: String, description: String?, author: String?, sourceUrl: String, image: RecipeImage, timing: RecipeTiming, serves: String?, ratingInfo: RecipeRatingInfo?, dateAdded: Date, dateModified: Date, ingredientSections: [RecipeIngredientGroup], stepSections: [RecipeStepSection], dominantColorHex: String?, homeId: UUID?) {
        self.id = id
        self.title = title
        self.description = description
        self.author = author
        self.sourceUrl = sourceUrl
        self.image = image
        self.timing = timing
        self.serves = serves
        self.ratingInfo = ratingInfo
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.ingredientSections = ingredientSections
        self.stepSections = stepSections
        self.dominantColorHex = dominantColorHex
        self.homeId = homeId
    }
}

public struct RecipeImage: Hashable, Sendable, Codable {
    /// A data representation of the image stored
    public let imageThumbnailData: Data?
    
    /// The url to the image originally imported
    public let imageUrl: String?
    
    public init(imageThumbnailData: Data?, imageUrl: String?) {
        self.imageThumbnailData = imageThumbnailData
        self.imageUrl = imageUrl
    }
}

public struct RecipeTiming: Hashable, Sendable, Codable {
    
    /// The total amount of minutes this recipe takes to prepare + cook
    public let totalTime: Double?
    
    /// The total amount of minutes this recipe takes to prepare for
    public let prepTime: Double?
    
    /// The total amount of minutes this reciep takes to cook
    public let cookTime: Double?
    
    public init(totalTime: Double?, prepTime: Double?, cookTime: Double?) {
        self.totalTime = totalTime
        self.prepTime = prepTime
        self.cookTime = cookTime
    }
}

public struct RecipeRatingInfo: Hashable, Sendable, Codable {
    
    /// The overall score rating the recipe has received
    public let overallRating: Double?
    
    /// An LLM summarisation of ratings received, may contain suggestions i.e. where multiple comments have rated this recipe as too thin etc.
    public let summarisedRating: String?
    
    /// The actual text ratings parsed from the original recipe
    public let ratings: [RecipeRating]
    
    public init(overallRating: Double?, summarisedRating: String?, ratings: [RecipeRating]) {
        self.overallRating = overallRating
        self.summarisedRating = summarisedRating
        self.ratings = ratings
    }
}
