//
//  HouseholdRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Combine
import Dependencies
import Observation
import SQLiteData
import Persistence
import Foundation
import Models

@Observable
public final class HouseholdRepository {
    private static let adoptionMarkerPrefix = "sporkast.supabase.homeAdoption.completed."

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchOne(DBHome.all) public var _dbHome

    public var home: Home? {
        if let _dbHome {
            return Home(from: _dbHome)
        } else { return nil }
    }
    
    public var homePublisher: AnyPublisher<DBHome?, Never> {
        $_dbHome.publisher.eraseToAnyPublisher()
    }

    public init() {}

    public func createHome(named name: String) async throws -> DBHome {
        let newDBHome = DBHome(id: UUID(), name: name)
        try await database.write { db in
            try DBHome.insert { newDBHome }.execute(db)
        }
        try await syncSupabaseHome(newDBHome)
        return newDBHome
    }

    public func deleteHome() async throws {
        let home = _dbHome
        if let home {
            try await SupabaseSyncService.shared.leaveHome(homeId: home.id, disbandIfOwner: true)
        }

        try await database.write { db in
            try DBHome.delete().execute(db)
        }
    }

    public func updateHomeName(name: String) async throws {
        guard let _dbHome else { return }
        
        try await database.write { db in
            try DBHome.find(_dbHome.id).update { $0.name = name }.execute(db)
        }
        try await syncSupabaseHome(DBHome(id: _dbHome.id, name: name))
    }

    public func createSupabaseInviteToken(expiresAt: Date? = nil) async throws -> String? {
        guard let _dbHome else { return nil }
        try await syncSupabaseHomeRecord(_dbHome)
        return try await SupabaseSyncService.shared.createInviteToken(homeId: _dbHome.id, expiresAt: expiresAt)
    }

    public func acceptSupabaseInviteToken(_ token: String) async throws -> UUID? {
        let homeId = try await SupabaseSyncService.shared.acceptInviteToken(token)
        await adoptPersonalEntitiesIntoHomeIfNeeded(homeId)
        return homeId
    }

    public func syncHomeEntities() async {
        guard let _dbHome else { return }
        RecipeDebugDiagnostics.logAppEvent("supabase startup household entity sync skipped homeId=\(_dbHome.id)")
    }

    public func supabaseResidents(for homeId: UUID) async throws -> [HomeResident] {
        return try await SupabaseSyncService.shared.homeResidents(homeId: homeId)
    }

    private func adoptPersonalEntitiesIntoHomeIfNeeded(_ homeId: UUID) async {
        let markerKey = Self.adoptionMarkerPrefix + homeId.uuidString
        guard !UserDefaults.standard.bool(forKey: markerKey) else { return }
        await assignPersonalEntitiesToHome(homeId)
        await syncAdoptedSupabaseScopes(homeId: homeId)
        UserDefaults.standard.set(true, forKey: markerKey)
    }

    private func assignPersonalEntitiesToHome(_ homeId: UUID) async {
        try? await database.write { db in
            try DBRecipe
                .where { $0.homeId.is(nil) }
                .update(set: { r in
                    r.homeId = #bind(homeId)
                })
                .execute(db)
        }

        try? await database.write { db in
            try DBMealplanEntry
                .where { $0.homeId.is(nil) }
                .update { $0.homeId = #bind(homeId) }
                .execute(db)
        }

        try? await database.write { db in
            try DBRecipeFolder
                .where { $0.homeId.is(nil) }
                .update { $0.homeId = #bind(homeId) }
                .execute(db)

            try DBRecipeTag
                .where { $0.homeId.is(nil) }
                .update { $0.homeId = #bind(homeId) }
                .execute(db)
        }

        try? await database.write { db in
            try DBShoppingList
                .where { $0.homeId.is(nil) }
                .update { $0.homeId = #bind(homeId) }
                .execute(db)
        }
    }

    private func syncSupabaseHome(_ home: DBHome) async throws {
        try await syncSupabaseHomeRecord(home)
        await adoptPersonalEntitiesIntoHomeIfNeeded(home.id)
    }

    private func syncSupabaseHomeRecord(_ home: DBHome) async throws {
        try await SupabaseSyncService.shared.syncHomeImmediately(home)
    }

    private func syncAdoptedSupabaseScopes(homeId: UUID) async {
        await SupabaseSyncService.shared.enqueueMealplanSnapshot(homeId: homeId)
        await SupabaseSyncService.shared.enqueueShoppingSnapshot(homeId: homeId)
        await SupabaseSyncService.shared.enqueueRecipeOrganizationSnapshot(homeId: homeId)
        await enqueueRecipeUpserts(homeId: homeId)
        await SupabaseSyncService.shared.drainOutbox()
    }

    private func enqueueRecipeUpserts(homeId: UUID) async {
        let recipeIds = (try? await database.read { db in
            try DBRecipe.all
                .fetchAll(db)
                .filter { $0.homeId == homeId }
                .map(\.id)
        }) ?? []

        for recipeId in recipeIds {
            await SupabaseSyncService.shared.enqueueRecipeUpsert(recipeId: recipeId, homeId: homeId)
        }
    }
}
