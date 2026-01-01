//
//  RecipeReview.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeReviewDTO: Codable {
    public let text: String
    public let rating: Int?
    
    init(text: String, rating: Int? = 0) {
        self.text = text
        self.rating = rating
    }
}
