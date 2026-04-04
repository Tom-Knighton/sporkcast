//
//  RecipeImporting.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import Environment
import Models

public protocol RecipeImporting: Sendable {
    func prepareImport(from source: RecipeImportSource, homeId: UUID?) async throws -> RecipeImportResult
    func detectDuplicates(for candidates: [RecipeImportCandidate], existing: [Recipe]) -> [UUID: DuplicateMatch]
    func persist(
        candidates: [RecipeImportCandidate],
        decisions: [UUID: DuplicateResolutionDecision],
        repository: RecipesRepository
    ) async throws
}
