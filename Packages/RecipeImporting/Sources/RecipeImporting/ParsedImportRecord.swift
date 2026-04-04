//
//  ParsedImportRecord.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation

struct ParsedImportRecord: Sendable {
    var record: ImportedRecipeRecord
    var provenance: RecipeImportProvenance
    var rawText: String
}
