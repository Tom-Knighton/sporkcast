//
//  RecipeReview.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeReviewDTO: Codable {
    public let text: String
    
    init(text: String) {
        self.text = text
    }
}
