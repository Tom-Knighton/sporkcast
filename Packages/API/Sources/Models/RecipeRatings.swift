//
//  RecipeRatings.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeRatings: Codable {
    public let overallRating: Double?
    public let reviews: [RecipeReview]?
    
    public init(overallRating: Double?, reviews: [RecipeReview]?) {
        self.overallRating = overallRating
        self.reviews = reviews
    }
}
