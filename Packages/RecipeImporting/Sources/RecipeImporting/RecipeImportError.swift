//
//  RecipeImportError.swift
//  Environment
//
//  Created by Codex on 27/03/2026.
//

import Foundation

public enum RecipeImportError: LocalizedError, Sendable {
    case unsupportedFileType(String)
    case unreadableFile
    case noRecipesDetected
    case apiReturnedNoRecipe

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "The file type \(ext) is not supported for recipe import."
        case .unreadableFile:
            return "This file could not be read."
        case .noRecipesDetected:
            return "No recipes were detected in this import source."
        case .apiReturnedNoRecipe:
            return "The API did not return recipe data for this import."
        }
    }
}
