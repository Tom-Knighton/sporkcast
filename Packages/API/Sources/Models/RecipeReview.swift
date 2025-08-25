//
//  RecipeReview.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeReview: Codable {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}
