//
//  ParsedImportRecord.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import Models

struct ParsedImportRecord: Sendable {
    var record: ImportedRecipeRecord
    var provenance: RecipeImportProvenance
    var enrichedRecipe: Recipe? = nil
    var rawText: String
}
