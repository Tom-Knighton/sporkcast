//
//  SettingsRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Foundation
import Observation
import SQLiteData
import Persistence

@Observable
@MainActor
public final class SettingsRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    public init() {}

    public func deleteAllData() async throws {
        try await database.write { db in
            try DBHome.delete().execute(db)
            try DBRecipe.delete().execute(db)
            try SyncMetadata.delete().execute(db)
            try DBMealplanEntry.delete().execute(db)
        }
    }

    public func exportDatabase() async throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let exportURL = tmpDir.appendingPathComponent("export.sqlite")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }

        try await database.write { try $0.execute(sql: "VACUUM INTO ?", arguments: [exportURL.path]) }
        return exportURL
    }
}
