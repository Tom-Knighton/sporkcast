//
//  MealplanRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Models
import Observation
import Persistence
import Foundation
import WidgetKit

@Observable
@MainActor
public final class MealplanRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    private var mealplanObservation: AnyDatabaseCancellable?

    private var dbMealplanEntries: [FullDBMealplanEntry] = []

    public var entries: [MealplanEntry] {
        dbMealplanEntries.compactMap { $0.toDomainModel() }
    }

    public init() {}

    public func loadEntries(startDate: Date, endDate: Date) async throws {
        mealplanObservation = observeAll(database, query: DBMealplanEntry.full(startDate: startDate, endDate: endDate)) { error in
            RecipeDebugDiagnostics.logAppEvent("mealplan observation failed error=\(error)")
        } onChange: { [weak self] entries in
            self?.dbMealplanEntries = entries
            self?.updateWidgetSnapshot()
        }
        updateWidgetSnapshot()
    }

    public func addRecipeEntry(date: Date, index: Int, recipeId: UUID, homeId: UUID?) async throws {
        let newEntry = DBMealplanEntry(id: UUID(), date: date, index: index, noteText: nil, recipeId: recipeId, homeId: homeId)
        try await database.write { db in
            try DBMealplanEntry.insert { newEntry }.execute(db)
        }
        await refreshWidgetSnapshot()
        await MealplanCalendarSyncService.shared.scheduleSync(trigger: .localMutation)
        await syncSupabaseEntries([newEntry.id], homeId: homeId)
    }

    public func addNoteEntry(date: Date, index: Int, text: String, homeId: UUID?) async throws {
        let newEntry = DBMealplanEntry(id: UUID(), date: date, index: index, noteText: text, recipeId: nil, homeId: homeId)
        try await database.write { db in
            try DBMealplanEntry.insert { newEntry }.execute(db)
        }
        await refreshWidgetSnapshot()
        await MealplanCalendarSyncService.shared.scheduleSync(trigger: .localMutation)
        await syncSupabaseEntries([newEntry.id], homeId: homeId)
    }

    public func updateNote(id: UUID, text: String) async throws {
        let homeId = try await homeIdForEntry(id)
        try await database.write { db in
            try DBMealplanEntry.find(id).update { $0.noteText = text }.execute(db)
        }
        await refreshWidgetSnapshot()
        await MealplanCalendarSyncService.shared.scheduleSync(trigger: .localMutation)
        await syncSupabaseEntries([id], homeId: homeId)
    }

    public func deleteEntry(id: UUID) async throws {
        let homeId = try await homeIdForEntry(id)
        try await MealplanCalendarSyncService.shared.prepareForLocalEntryDeletion(entryIDs: [id])
        try await database.write { db in
            try DBMealplanEntry.find(id).delete().execute(db)
        }
        await refreshWidgetSnapshot()
        await MealplanCalendarSyncService.shared.scheduleSync(trigger: .localMutation)
        await SupabaseSyncService.shared.deleteMealplanEntry(id, homeId: homeId)
    }

    public func insertRandomMeal(date: Date, index: Int, homeId: UUID?) async throws {
        let recipe = try await database.read { db in
            try DBRecipe.fetchOne(db, sql: "SELECT * FROM Recipes ORDER BY RANDOM() LIMIT 1")
        }

        guard let recipe else { return }

        let newEntry = DBMealplanEntry(id: UUID(), date: date, index: index, noteText: nil, recipeId: recipe.id, homeId: homeId)
        try await database.write { db in
            try DBMealplanEntry.insert { newEntry }.execute(db)
        }
        await refreshWidgetSnapshot()
        await MealplanCalendarSyncService.shared.scheduleSync(trigger: .localMutation)
        await syncSupabaseEntries([newEntry.id], homeId: homeId)
    }

    public func moveEntry(entryId: UUID, to date: Date, index: Int, existingEntries: [MealplanEntry]) async throws {
        let homeId = try await homeIdForEntry(entryId)
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
        await refreshWidgetSnapshot()
        await MealplanCalendarSyncService.shared.scheduleSync(trigger: .localMutation)
        await syncSupabaseEntries([entryId] + existingEntries.map(\.id), homeId: homeId)
    }

    public func refreshWidgetSnapshot(now: Date = .now, calendar: Calendar = .current) async {
        let range = MealplanWidgetSnapshotStore.dateRange(now: now, calendar: calendar)

        do {
            try await loadEntries(startDate: range.lowerBound, endDate: range.upperBound)
        } catch {
            print(error.localizedDescription)
        }
    }

    private func updateWidgetSnapshot(now: Date = .now, calendar: Calendar = .current) {
        MealplanWidgetSnapshotStore.write(entries: entries, now: now, calendar: calendar)
        WidgetCenter.shared.reloadTimelines(ofKind: MealplanWidgetSnapshotStore.widgetKind)
    }

    private func syncSupabaseSnapshot(homeId: UUID? = nil) async {
        await SupabaseSyncService.shared.enqueueMealplanSnapshot(homeId: homeId)
        await SupabaseSyncService.shared.drainOutbox()
    }

    private func syncSupabaseEntries(_ entryIds: [UUID], homeId: UUID? = nil) async {
        do {
            try await SupabaseSyncService.shared.pushMealplanEntries(entryIds: entryIds)
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase mealplan direct push failed count=\(entryIds.count) error=\(error)")
            await syncSupabaseSnapshot(homeId: homeId)
        }
    }

    private func homeIdForEntry(_ id: UUID) async throws -> UUID? {
        try await database.read { db in
            try DBMealplanEntry.find(id).fetchOne(db)?.homeId
        }
    }
}
