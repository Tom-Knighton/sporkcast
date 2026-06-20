//
//  sporkcastApp.swift
//  sporkcast
//
//  Created by Tom Knighton on 22/08/2025.
//

import SwiftUI
import API
import SwiftData
import Persistence
import Design
import Environment

@main
struct SporkcastApp: App {
    
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    init() {
        SupabaseInstallState.clearPersistedSessionAfterFreshInstallIfNeeded()
        var appDatabase: (any DatabaseWriter)!
        prepareDependencies {
            appDatabase = try! AppDatabaseFactory.makeAppDatabase(tracer: { description in
#if DEBUG
//                print(description)
#endif
//                RecipeDebugDiagnostics.logSQLIfRecipeMutation(description)
            })
            $0.defaultDatabase = appDatabase
        }
        
        if #available(iOS 27.0, *) {
            PlannedMealSpotlightIndexer.shared.start(database: appDatabase)
        }
        

        RecipeDebugDiagnostics.logAppEvent("app init completed")
        Task {
            await RecipeDebugDiagnostics.logRecipeCounts("app init", database: appDatabase)
            if #available(iOS 27.0, *) {
                await PlannedMealSpotlightIndexer.shared.reindexAll()
            }
            
            await SupabaseSyncService.shared.start()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppContent()
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
}

// Tabs:
// - Cookbook (Ask recipe about changes w/ AI?)
// - MealPlan (Groceries)
// - Discover/AI Ideas
// - Groceries (if enabled as tab)
// - Settings
