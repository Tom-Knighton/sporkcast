//
//  sporkcastApp.swift
//  sporkcast
//
//  Created by Tom Knighton on 22/08/2025.
//

import SwiftUI
import API
import SwiftData
import SQLiteData
import OSLog
import Persistence

@main
struct SporkcastApp: App {
    
    init() {
        prepareDependencies {
            $0.defaultDatabase = try! Database().appDb()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppContent()
                .modelContainer(V1Models.sharedContainer!)
        }
    }
}

private struct Database {
    private let logger = Logger(subsystem: "Sporkast", category: "Database")
    
    public func appDb() throws -> any DatabaseWriter {
        @Dependency(\.context) var context
        var config = Configuration()
        
#if DEBUG
        config.prepareDatabase { db in
            db.trace(options: .profile) {
                if context == .preview {
                    print("\($0.expandedDescription)")
                } else {
                    logger.debug("\($0.expandedDescription)")
                }
            }
        }
#endif
        
        let database = try defaultDatabase(configuration: config)
        logger.info("open \(database.path)")
        
        var migrator = DatabaseMigrator()
#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif
        
        SchemaV1.migrate(&migrator)
        
        try migrator.migrate(database)
        
        return database
    }
}



// Tabs:
// - Cookbook (Ask recipe about changes w/ AI?)
// - MealPlan (Groceries)
// - Discover/AI Ideas
// - Groceries (if enabled as tab)
// - Settings
