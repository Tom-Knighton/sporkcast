//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeStepSectionDTO: Codable {
    public let title: String?
    public let steps: [RecipeStepDTO]?
    
    public init(title: String?, steps: [RecipeStepDTO]?) {
        self.title = title
        self.steps = steps
    }
}
