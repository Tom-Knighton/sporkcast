//
//  MealplanRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Models
import Observation
import SQLiteData
import Persistence
import Foundation

@Observable
@MainActor
public final class MealplanRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchAll private var dbMealplanEntries: [FullDBMealplanEntry]

    public var entries: [MealplanEntry] {
        dbMealplanEntries.compactMap { $0.toDomainModel() }
    }

    public init() {}

    public func loadEntries(startDate: Date, endDate: Date) async throws {
        try await $dbMealplanEntries.load(DBMealplanEntry.full(startDate: startDate, endDate: endDate))
    }

    public func addRecipeEntry(date: Date, index: Int, recipeId: UUID, homeId: UUID?) async throws {
        let newEntry = DBMealplanEntry(id: UUID(), date: date, index: index, noteText: nil, recipeId: recipeId, homeId: homeId)
        try await database.write { db in
            try DBMealplanEntry.insert { newEntry }.execute(db)
        }
    }

    public func addNoteEntry(date: Date, index: Int, text: String, homeId: UUID?) async throws {
        let newEntry = DBMealplanEntry(id: UUID(), date: date, index: index, noteText: text, recipeId: nil, homeId: homeId)
        try await database.write { db in
            try DBMealplanEntry.insert { newEntry }.execute(db)
        }
    }

    public func updateNote(id: UUID, text: String) async throws {
        try await database.write { db in
            try DBMealplanEntry.find(id).update { $0.noteText = text }.execute(db)
        }
    }

    public func deleteEntry(id: UUID) async throws {
        try await database.write { db in
            try DBMealplanEntry.find(id).delete().execute(db)
        }
    }

    public func insertRandomMeal(date: Date, index: Int, homeId: UUID?) async throws {
        let recipe = try await database.read { db in
            try DBRecipe
                .order { _ in #sql("RANDOM()") }
                .fetchOne(db)
        }

        guard let recipe else { return }

        let newEntry = DBMealplanEntry(id: UUID(), date: date, index: index, noteText: nil, recipeId: recipe.id, homeId: homeId)
        try await database.write { db in
            try DBMealplanEntry.insert { newEntry }.execute(db)
        }
    }

    public func moveEntry(entryId: UUID, to date: Date, index: Int, existingEntries: [MealplanEntry]) async throws {
        try await database.write { db in
            try DBMealplanEntry
                .find(entryId)
                .update { entry in
                    entry.date = date
                    entry.index = index
                }
                .execute(db)

            for entry in existingEntries where entry.id != entryId && entry.index >= index {
                try DBMealplanEntry
                    .find(entry.id)
                    .update { $0.index = $0.index + 1 }
                    .execute(db)
            }
        }
    }
}
