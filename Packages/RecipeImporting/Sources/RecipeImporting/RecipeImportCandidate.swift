//
//  RecipeImportCandidate.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import Models

public struct RecipeImportCandidate: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var recipe: Recipe
    public let provenance: RecipeImportProvenance
    public var quality: ImportQuality
    public var usedAPIFallback: Bool
    public var rawTextForFallback: String

    public init(
        id: UUID = UUID(),
        recipe: Recipe,
        provenance: RecipeImportProvenance,
        quality: ImportQuality,
        usedAPIFallback: Bool,
        rawTextForFallback: String
    ) {
        self.id = id
        self.recipe = recipe
        self.provenance = provenance
        self.quality = quality
        self.usedAPIFallback = usedAPIFallback
        self.rawTextForFallback = rawTextForFallback
    }
}

public struct RecipeImportResult: Sendable, Hashable {
    public var candidates: [RecipeImportCandidate]
    public var duplicateMatches: [UUID: DuplicateMatch]

    public init(candidates: [RecipeImportCandidate], duplicateMatches: [UUID: DuplicateMatch]) {
        self.candidates = candidates
        self.duplicateMatches = duplicateMatches
    }
}
