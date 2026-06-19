//
//  PlannedMealSpotlightIndexer.swift
//  sporkcast
//
//  Created by Tom Knighton on 19/06/2026.
//

import AppIntents
import CoreSpotlight
import Environment
import Foundation
import Models
import Persistence

final class PlannedMealSpotlightIndexer {
    static let shared = PlannedMealSpotlightIndexer()

    private var database: (any DatabaseReader)?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start(database: any DatabaseReader) {
        self.database = database
        guard observers.isEmpty else { return }

        observers.append(
            NotificationCenter.default.addObserver(
                forName: MealplanSpotlightEvents.indexRequested,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let ids = notification.object as? [MealplanEntry.ID] else { return }
                Task { await self?.index(ids: ids) }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: MealplanSpotlightEvents.deleteRequested,
                object: nil,
                queue: nil
            ) { notification in
                guard let ids = notification.object as? [MealplanEntry.ID] else { return }
                Task { await Self.delete(ids: ids) }
            }
        )
    }

    func reindexAll() async {
        guard let database else { return }

        do {
            let entities = try await plannedMealEntities(database: database)
            try await CSSearchableIndex.default().indexAppEntities(entities)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("planned meal spotlight reindex failed error=\(error)")
        }
    }

    private func index(ids: [MealplanEntry.ID]) async {
        guard let database else { return }

        do {
            let entities = try await plannedMealEntities(ids: ids, database: database)
            try await CSSearchableIndex.default().indexAppEntities(entities)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("planned meal spotlight index failed count=\(ids.count) error=\(error)")
        }
    }

    private static func delete(ids: [MealplanEntry.ID]) async {
        do {
            try await CSSearchableIndex.default().deleteAppEntities(
                identifiedBy: ids,
                ofType: PlannedMealEntity.self
            )
        } catch {
            RecipeDebugDiagnostics.logAppEvent("planned meal spotlight delete failed count=\(ids.count) error=\(error)")
        }
    }

    private func plannedMealEntities(ids: [MealplanEntry.ID], database: any DatabaseReader) async throws -> [PlannedMealEntity] {
        try await database.read { db in
            try DBMealplanEntry
                .full(ids: ids)
                .fetchAll(db)
                .compactMap { PlannedMealEntity(mealplanEntry: $0.toDomainModel()) }
        }
    }

    private func plannedMealEntities(database: any DatabaseReader) async throws -> [PlannedMealEntity] {
        try await database.read { db in
            try DBMealplanEntry
                .full
                .fetchAll(db)
                .compactMap { PlannedMealEntity(mealplanEntry: $0.toDomainModel()) }
        }
    }
}
