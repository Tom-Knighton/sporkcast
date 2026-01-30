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
    public var title: String
    
    /// An optional brief description of the recipe
    public var description: String?
    
    /// An Apple Intelligence generated summary of reviews/sentiment
    public let summarisedTip: String?
    
    /// The original creator/poster of the recipe, occasionally will be a friendly version of the site
    public var author: String?
    
    /// The url the recipe was originally imported from - and where users should be directed to if they wish to view the original recipe
    public var sourceUrl: String
    
    /// Details of the image to display for the recipe
    public var image: RecipeImage
    
    /// How long the recipe takes to cook/prepare
    public var timing: RecipeTiming
    
    /// If present, what the recipe 'serves' i.e. '6' (for 6 people). Occasionally recipes will format this as '1 loaf' etc.
    public var serves: String?
    
    /// Details on ratings/reviews
    public var ratingInfo: RecipeRatingInfo?
    
    /// The date the user added/imported this recipe
    public var dateAdded: Date
    
    /// The date the user last modified this recipe, i.e. by editing it manually, reimporting...
    public var dateModified: Date
    
    /// Groups of ingredients in the recipe
    public var ingredientSections: [RecipeIngredientGroup]
    
    /// Sections of steps in the recipe
    public var stepSections: [RecipeStepSection]

    /// The primary colour associated with the recipe
    public var dominantColorHex: String?
    
    /// The id of the home this recipe is a part of, if any
    public var homeId: UUID?

    
    public init(id: UUID, title: String, description: String?, summarisedTip: String?, author: String?, sourceUrl: String, image: RecipeImage, timing: RecipeTiming, serves: String?, ratingInfo: RecipeRatingInfo?, dateAdded: Date, dateModified: Date, ingredientSections: [RecipeIngredientGroup], stepSections: [RecipeStepSection], dominantColorHex: String?, homeId: UUID?) {
        self.id = id
        self.title = title
        self.description = description
        self.summarisedTip = summarisedTip
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
    public var totalTime: Double?
    
    /// The total amount of minutes this recipe takes to prepare for
    public var prepTime: Double?
    
    /// The total amount of minutes this reciep takes to cook
    public var cookTime: Double?
    
    public init(totalTime: Double?, prepTime: Double?, cookTime: Double?) {
        self.totalTime = totalTime
        self.prepTime = prepTime
        self.cookTime = cookTime
    }
}

public struct RecipeRatingInfo: Hashable, Sendable, Codable {
    
    /// The overall score rating the recipe has received
    public let overallRating: Double?
    
    /// The total number of ratings the recipe has received
    public let totalRatings: Int?
    
    /// An LLM summarisation of ratings received, may contain suggestions i.e. where multiple comments have rated this recipe as too thin etc.
    public let summarisedRating: String?
    
    /// The actual text ratings parsed from the original recipe
    public let ratings: [RecipeRating]
    
    public init(overallRating: Double?, totalRatings: Int, summarisedRating: String?, ratings: [RecipeRating]) {
        self.overallRating = overallRating
        self.totalRatings = totalRatings
        self.summarisedRating = summarisedRating
        self.ratings = ratings
    }
}
