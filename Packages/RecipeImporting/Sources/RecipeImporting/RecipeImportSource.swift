//
//  RecipeImportSource.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation

public enum RecipeImportSource: Sendable, Hashable {
    case webURL(URL)
    case fileURL(URL, vendorHint: RecipeImportVendor?)
    case markdownText(String)
    case webSelection(text: String, sourceURL: URL?)
    case ocrText(String)

    public var sourceHint: String? {
        switch self {
        case .webURL(let url):
            return url.absoluteString
        case .fileURL(let url, _):
            return url.lastPathComponent
        case .markdownText:
            return "markdown"
        case .webSelection(_, let sourceURL):
            return sourceURL?.absoluteString ?? "web-selection"
        case .ocrText:
            return "ocr"
        }
    }

    public var vendorHint: RecipeImportVendor? {
        switch self {
        case .fileURL(_, let vendorHint):
            return vendorHint
        default:
            return nil
        }
    }
}

public enum RecipeImportMode: String, Sendable, Codable, Hashable {
    case web
    case archive
    case file
    case markdown
    case webSelection = "web-selection"
    case ocr
}

public enum RecipeImportVendor: String, Sendable, Codable, Hashable {
    case web
    case sporkcast
    case pestle
    case crouton
    case paprika
    case markdown
    case unknown
}

public struct RecipeImportProvenance: Sendable, Codable, Hashable {
    public let mode: RecipeImportMode
    public let vendor: RecipeImportVendor
    public let sourceHint: String?

    public init(mode: RecipeImportMode, vendor: RecipeImportVendor, sourceHint: String?) {
        self.mode = mode
        self.vendor = vendor
        self.sourceHint = sourceHint
    }
}
