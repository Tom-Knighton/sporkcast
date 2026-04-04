//
//  RecipeExportFormat.swift
//  Environment
//
//  Created by Tom Knighton on 03/04/2026.
//

import Foundation

public enum RecipeExportFormat: String, CaseIterable, Sendable, Identifiable {
    case sporkast
    case markdown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sporkast:
            return "Sporkast Backup"
        case .markdown:
            return "Markdown"
        }
    }

    public var subtitle: String {
        switch self {
        case .sporkast:
            return "Best for importing back into Sporkast."
        case .markdown:
            return "Exports each recipe as a RecipeMD markdown file."
        }
    }

    public var fileExtension: String {
        switch self {
        case .sporkast:
            return "sporkast"
        case .markdown:
            return "md"
        }
    }

    public var directoryPrefix: String {
        switch self {
        case .sporkast:
            return "sporkcast-recipe-export"
        case .markdown:
            return "sporkcast-recipe-markdown-export"
        }
    }

    public var schemaVersion: Int {
        switch self {
        case .sporkast:
            return 1
        case .markdown:
            return 1
        }
    }
}
