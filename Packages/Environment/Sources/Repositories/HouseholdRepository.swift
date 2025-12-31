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
import CloudKit
import Models

@Observable
public final class HouseholdRepository {

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
        return newDBHome
    }

    public func deleteHome() async throws {
        try await database.write { db in
            try DBHome.delete().execute(db)
        }
    }

    public func updateHomeName(name: String) async throws {
        guard let _dbHome else { return }
        
        try await database.write { db in
            try DBHome.find(_dbHome.id).update { $0.name = name }.execute(db)
        }
    }

    public func shareHome() async throws -> CKShare? {
        guard let _dbHome else { return nil }
        
        let share = try await database.read { db in
            try SyncMetadata
                .find(_dbHome.syncMetadataID)
                .select(\.share)
                .fetchOne(db)
        }
        
        return share as? CKShare
    }

    public func homeShareMetadata() async throws -> [SyncMetadata] {
        guard let _dbHome else { return [] }
        
        return try await database.read { db in
            try SyncMetadata
                .find(_dbHome.syncMetadataID)
                .fetchAll(db)
        }
    }

    public func syncHomeEntities() async {
        guard let _dbHome else { return }
        
        try? await database.write { db in
            try DBRecipe
                .where { $0.id != _dbHome.id }
                .update { $0.homeId = _dbHome.id }
                .execute(db)
        }

        try? await database.write { db in
            try DBMealplanEntry
                .where { $0.id != _dbHome.id }
                .update { $0.homeId = _dbHome.id }
                .execute(db)
        }
    }
}
