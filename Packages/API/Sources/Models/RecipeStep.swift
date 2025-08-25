//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeStep: Codable {
    public let step: String
    
    public init(step: String) {
        self.step = step
    }
}
