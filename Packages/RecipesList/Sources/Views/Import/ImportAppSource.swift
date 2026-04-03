//
//  ImportAppSource.swift
//  RecipesList
//
//  Created by Codex on 01/04/2026.
//

import RecipeImporting
import UniformTypeIdentifiers

enum ImportAppSource: String, CaseIterable, Identifiable {
    case pestle
    case crouton
    case paprika

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pestle:
            return "Pestle"
        case .crouton:
            return "Crouton"
        case .paprika:
            return "Paprika"
        }
    }

    var subtitle: String {
        switch self {
        case .pestle:
            return "Accepts .pestle export files"
        case .crouton:
            return "Accepts .zip exports (with .crumb recipes) or .crumb files"
        case .paprika:
            return "Accepts .paprikarecipes or .zip exports"
        }
    }

    var icon: String {
        switch self {
        case .pestle:
            return "fork.knife.circle"
        case .crouton:
            return "archivebox.circle"
        case .paprika:
            return "book.circle"
        }
    }

    var vendorHint: RecipeImportVendor {
        switch self {
        case .pestle:
            return .pestle
        case .crouton:
            return .crouton
        case .paprika:
            return .paprika
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .pestle:
            return [.pestleExport]
        case .crouton:
            return [.zip, .croutonCrumb]
        case .paprika:
            return [.paprikaExport, .zip]
        }
    }
}

private extension UTType {
    static var pestleExport: UTType {
        UTType(filenameExtension: "pestle") ?? .json
    }

    static var paprikaExport: UTType {
        UTType(filenameExtension: "paprikarecipes") ?? .zip
    }

    static var croutonCrumb: UTType {
        UTType(filenameExtension: "crumb") ?? .json
    }
}
