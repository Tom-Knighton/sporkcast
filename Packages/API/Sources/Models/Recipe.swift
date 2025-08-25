//
//  Recipe.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct Recipe: Codable {
    
    public let title: String
    public let description: String?
    public let author: String?
    public let imageUrl: String?
    public let minutesToPrepare: Double?
    public let minutesToCook: Double?
    public let totalMins: Double?
    public let serves: String?
    public let url: String
    
    public let ingredients: [String]
    public let tags: [String]
    public let stepSections: [RecipeStepSection]
    public let ratings: RecipeRatings
    
    public init(title: String, description: String?, author: String?, imageUrl: String?, minutesToPrepare: Double?, minutesToCook: Double?, totalMins: Double?, serves: String?, url: String, ingredients: [String], tags: [String], stepSections: [RecipeStepSection], ratings: RecipeRatings) {
        self.title = title
        self.description = description
        self.author = author
        self.imageUrl = imageUrl
        self.minutesToPrepare = minutesToPrepare
        self.minutesToCook = minutesToCook
        self.totalMins = totalMins
        self.serves = serves
        self.url = url
        self.ingredients = ingredients
        self.tags = tags
        self.stepSections = stepSections
        self.ratings = ratings
    }
}
