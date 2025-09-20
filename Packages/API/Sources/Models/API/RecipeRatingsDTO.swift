//
//  RecipeRatings.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeRatingsDTO: Codable {
    public let overallRating: Double?
    public let reviews: [RecipeReviewDTO]?
    
    init(overallRating: Double?, reviews: [RecipeReviewDTO]?) {
        self.overallRating = overallRating
        self.reviews = reviews
    }
}
