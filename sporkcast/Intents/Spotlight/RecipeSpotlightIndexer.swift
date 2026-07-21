//
//  RecipeSpotlightIndexer.swift
//  sporkcast
//
//  Created by Tom Knighton on 29/06/2026.
//

import AppIntents
import CoreSpotlight
import Environment
import Foundation
import Models
import Persistence

@available(anyAppleOS 27.0, *)
final class RecipeSpotlightIndexer {
    static let shared = RecipeSpotlightIndexer()

    private var database: (any DatabaseReader)?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start(database: any DatabaseReader) {
        self.database = database
        guard observers.isEmpty else { return }

        observers.append(
            NotificationCenter.default.addObserver(
                forName: RecipeSpotlightEvents.indexRequested,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let ids = notification.object as? [Recipe.ID] else { return }
                Task { await self?.index(ids: ids) }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: RecipeSpotlightEvents.deleteRequested,
                object: nil,
                queue: nil
            ) { notification in
                guard let ids = notification.object as? [Recipe.ID] else { return }
                Task { await Self.delete(ids: ids) }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: RecipeSpotlightEvents.deleteAllRequested,
                object: nil,
                queue: nil
            ) { _ in
                Task { await Self.deleteAll() }
            }
        )
    }

    func reindexAll() async {
        guard let database else { return }

        do {
            let entities = try await recipeEntities(database: database)
            try await CSSearchableIndex.default().indexAppEntities(entities)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("recipe spotlight reindex failed error=\(error)")
        }
    }

    private func index(ids: [Recipe.ID]) async {
        guard let database else { return }

        do {
            let entities = try await recipeEntities(ids: ids, database: database)
            try await CSSearchableIndex.default().indexAppEntities(entities)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("recipe spotlight index failed count=\(ids.count) error=\(error)")
        }
    }

    private static func delete(ids: [Recipe.ID]) async {
        do {
            try await CSSearchableIndex.default().deleteAppEntities(
                identifiedBy: ids,
                ofType: RecipeEntity.self
            )
        } catch {
            RecipeDebugDiagnostics.logAppEvent("recipe spotlight delete failed count=\(ids.count) error=\(error)")
        }
    }

    private static func deleteAll() async {
        do {
            try await CSSearchableIndex.default().deleteAppEntities(ofType: RecipeEntity.self)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("recipe spotlight delete all failed error=\(error)")
        }
    }

    private func recipeEntities(ids: [Recipe.ID], database: any DatabaseReader) async throws -> [RecipeEntity] {
        try await database.read { db in
            try DBRecipe
                .full
                .where { ids.contains($0.id) }
                .fetchAll(db)
                .map { RecipeEntity(recipe: $0.toDomainModel()) }
        }
    }

    private func recipeEntities(database: any DatabaseReader) async throws -> [RecipeEntity] {
        try await database.read { db in
            try DBRecipe
                .full
                .fetchAll(db)
                .map { RecipeEntity(recipe: $0.toDomainModel()) }
        }
    }
}
