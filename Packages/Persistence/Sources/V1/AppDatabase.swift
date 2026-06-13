//
//  AppDatabase.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-27.
//

import OSLog
import GRDB

public enum AppDatabaseFactory {

    public static func makeAppDatabase(
        path: String? = nil,
        configuration: Configuration = Configuration(),
        tracer: (@Sendable (String) -> Void)? = nil
    ) throws -> any DatabaseWriter {
        var config = configuration

        config.prepareDatabase { [tracer] db in
            if let tracer {
                db.trace(options: .profile) { [tracer] in
                    tracer($0.expandedDescription)
                }
            }
        }

        let database = try defaultDatabase(path: path, configuration: config)

        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange =
            ProcessInfo.processInfo.environment["SPORKCAST_ERASE_DB_ON_SCHEMA_CHANGE"] == "1"
        #endif
        SchemaV1.migrate(&migrator)
        try migrator.migrate(database)

        return database
    }
}
