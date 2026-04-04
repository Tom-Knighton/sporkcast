//
//  RecipeExportError.swift
//  Environment
//
//  Created by Tom Knighton on 03/04/2026.
//

import Foundation

public enum RecipeExportError: Error, Sendable, LocalizedError {
    case noRecipesAvailable
    case failedToEncodeRecipe(recipeId: UUID)
    case failedToCreateArchive

    public var errorDescription: String? {
        switch self {
        case .noRecipesAvailable:
            return "No recipes are available to export."
        case .failedToEncodeRecipe(let recipeId):
            return "Failed to encode recipe \(recipeId.uuidString)."
        case .failedToCreateArchive:
            return "Could not generate the ZIP export."
        }
    }
}
