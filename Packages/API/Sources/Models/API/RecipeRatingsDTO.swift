//
//  RecipeRatings.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeRatingsDTO: Codable {
    public let overallRating: Double?
    public let totalRatings: Int
    public let reviews: [RecipeReviewDTO]?
    
    init(overallRating: Double?, totalRatings: Int, reviews: [RecipeReviewDTO]?) {
        self.overallRating = overallRating
        self.totalRatings = totalRatings
        self.reviews = reviews
    }
}
