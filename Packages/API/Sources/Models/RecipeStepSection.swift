//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeStepSection: Codable {
    public let title: String?
    public let steps: [RecipeStep]?
    
    public init(title: String?, steps: [RecipeStep]?) {
        self.title = title
        self.steps = steps
    }
}
