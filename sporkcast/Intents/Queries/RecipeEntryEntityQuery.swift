//
//  RecipeEntryEntityQuery.swift
//  sporkcast
//
//  Created by Tom Knighton on 29/06/2026.
//

import AppIntents
import CoreSpotlight
import Environment

@available(anyAppleOS 27.0, *)
public struct RecipeEntryEntityQuery: EntityStringQuery {
    
    @MainActor private var repository = RecipesRepository(observesChanges: false)
    
    public init() {}
    
    public func entities(for identifiers: [RecipeEntity.ID]) async throws -> [RecipeEntity] {
        try await repository.getIntentSummariesById(identifiers).map { RecipeEntity(summary: $0) }
    }
    
    public func suggestedEntities() async throws -> [RecipeEntity] {
        try await repository.getIntentSuggestions().map { RecipeEntity(summary: $0) }
    }

    public func entities(matching string: String) async throws -> [RecipeEntity] {
        try await repository.getIntentSummariesByLookup(string, limit: 20).map { RecipeEntity(summary: $0) }
    }
    
}

@available(anyAppleOS 27.0, *)
extension RecipeEntryEntityQuery: IndexedEntityQuery {
    public func reindexEntities(for identifiers: [RecipeEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await entities(for: identifiers)
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }

    public func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await repository.getIntentSuggestions(limit: .max).map { RecipeEntity(summary: $0) }
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }
}
