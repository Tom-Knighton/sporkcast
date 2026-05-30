//
//  RecipeImportError.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import API

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
            return "We couldn't find a complete recipe in that import source."
        }
    }

    public static func customerFacingMessage(
        for error: Error,
        fallbackMessage: String = "We couldn't import that recipe right now. Please try again.",
        decodingMessage: String = "The recipe data came back in an unexpected format. Please try another page."
    ) -> String {
        if error is DecodingError {
            return decodingMessage
        }

        if let importError = error as? RecipeImportError,
           let message = importError.errorDescription,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        if let clientError = error as? APIClient.ClientError {
            return customerFacingMessage(for: clientError, fallbackMessage: fallbackMessage)
        }

        if error is URLError {
            return "We couldn't reach the recipe source. Check your connection and try again."
        }

        return fallbackMessage
    }

    private static func customerFacingMessage(
        for clientError: APIClient.ClientError,
        fallbackMessage: String
    ) -> String {
        switch clientError {
        case .invalidUrl:
            return "That recipe link doesn't look valid. Check the URL and try again."
        case .unexpectedError:
            return fallbackMessage
        case .httpError(let statusCode, _):
            switch statusCode {
            case 400, 422:
                return "We couldn't find enough recipe details on that page. Try another page or paste the recipe text instead."
            case 401, 403:
                return "We couldn't access that recipe page. Some sites block imports, so try copying the recipe text instead."
            case 404, 410:
                return "We couldn't find that recipe page. Check the link and try again."
            case 408, 429:
                return "Recipe import is busy right now. Wait a moment, then try again."
            case 500...599:
                return "Recipe import is having trouble right now. Please try again in a bit."
            default:
                return fallbackMessage
            }
        }
    }
}
