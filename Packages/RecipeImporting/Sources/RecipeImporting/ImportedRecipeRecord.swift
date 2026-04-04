//
//  ImportedRecipeRecord.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation

struct ImportedRecipeRecord: Sendable {
    var title: String
    var description: String?
    var author: String?
    var sourceURL: String?
    var imageURL: String?
    var imageData: Data? = nil
    var serves: String?
    var prepMinutes: Double?
    var cookMinutes: Double?
    var totalMinutes: Double?
    var ingredientSections: [ImportedIngredientSection]
    var stepSections: [ImportedStepSection]
}

struct ImportedIngredientSection: Sendable {
    var title: String
    var ingredients: [String]
}

struct ImportedStepSection: Sendable {
    var title: String
    var steps: [String]
}
