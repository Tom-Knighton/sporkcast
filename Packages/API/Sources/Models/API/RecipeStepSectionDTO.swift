//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeStepSectionDTO: Codable {
    let title: String?
    let steps: [RecipeStepDTO]?
    
    init(title: String?, steps: [RecipeStepDTO]?) {
        self.title = title
        self.steps = steps
    }
}
