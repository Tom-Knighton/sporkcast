//
//  RecipeSearchQueryEntity.swift
//  sporkcast
//
//  Created by Tom Knighton on 12/07/2026.
//

import AppIntents
import Environment
import Foundation

@available(anyAppleOS 27.0, *)
public struct RecipeSearchQueryEntity: AppEntity, Identifiable, Sendable {
    public static let defaultQuery = RecipeSearchQueryEntityQuery()
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe Search")

    public let id: String
    public let query: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(query)")
    }

    public init(query: String) {
        let normalizedQuery = RecipeSearchNormalizer.normalizedQuery(query)
        let trimmedQuery = normalizedQuery.isEmpty
            ? query.trimmingCharacters(in: .whitespacesAndNewlines)
            : normalizedQuery
        self.query = trimmedQuery
        self.id = trimmedQuery.localizedLowercase
    }
}

@available(anyAppleOS 27.0, *)
public struct RecipeSearchQueryEntityQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [RecipeSearchQueryEntity.ID]) async throws -> [RecipeSearchQueryEntity] {
        identifiers
            .map { RecipeSearchQueryEntity(query: $0) }
            .filter { !$0.query.isEmpty }
    }

    public func suggestedEntities() async throws -> [RecipeSearchQueryEntity] {
        []
    }

    public func entities(matching string: String) async throws -> [RecipeSearchQueryEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return [RecipeSearchQueryEntity(query: query)]
    }
}
