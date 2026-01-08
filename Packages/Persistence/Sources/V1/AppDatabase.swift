//
//  AppDatabase.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-27.
//

import Dependencies
import OSLog
import SQLiteData

public enum AppDatabaseFactory {

    public static func makeAppDatabase(
        configuration: Configuration = Configuration(),
        tracer: (@Sendable (String) -> Void)? = nil
    ) throws -> any DatabaseWriter {
        @Dependency(\.context) var context
        var config = configuration

        config.prepareDatabase { [tracer] db in
            
            if context != .preview {
                try db.attachMetadatabase()
            }

            #if DEBUG
            if let tracer {
                db.trace(options: .profile) { [tracer] in
                    tracer($0.expandedDescription)
                }
            }
            #endif
        }

        let database = try defaultDatabase(configuration: config)

        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        SchemaV1.migrate(&migrator)
        try migrator.migrate(database)

        return database
    }
}

