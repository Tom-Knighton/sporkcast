//
//  RecipeExportFormat.swift
//  Environment
//
//  Created by Tom Knighton on 03/04/2026.
//

import Foundation

public enum RecipeExportFormat: String, CaseIterable, Sendable, Identifiable {
    case sporkast

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sporkast:
            return "Sporkast JSON"
        }
    }

    public var subtitle: String {
        switch self {
        case .sporkast:
            return "Exports each recipe as an individual .sporkast file."
        }
    }

    public var fileExtension: String {
        switch self {
        case .sporkast:
            return "sporkast"
        }
    }

    public var directoryPrefix: String {
        switch self {
        case .sporkast:
            return "sporkcast-recipe-export"
        }
    }

    public var schemaVersion: Int {
        switch self {
        case .sporkast:
            return 1
        }
    }
}
