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
import Persistence
import CloudKit
import Design

@main
struct SporkcastApp: App {
    
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    init() {
        prepareDependencies {
            $0.defaultDatabase = try! AppDatabaseFactory.makeAppDatabase(tracer: { description in
                #if DEBUG
                    print(description)
                #endif
            })

            $0.defaultSyncEngine = try! SyncEngine(
                for: $0.defaultDatabase,
                tables: DBHome.self, DBRecipe.self, DBRecipeIngredientGroup.self, DBRecipeIngredient.self, DBRecipeStepGroup.self, DBRecipeStep.self, DBRecipeStepTiming.self, DBRecipeStepTemperature.self, DBRecipeImage.self
            )
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
    
    @Dependency(\.defaultSyncEngine) private var syncEngine
    var window: UIWindow?
    
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        HouseholdService.shared.pendingInvite = cloudKitShareMetadata
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ckData = connectionOptions.cloudKitShareMetadata else { return }
        
        HouseholdService.shared.pendingInvite = ckData
    }
}

// Tabs:
// - Cookbook (Ask recipe about changes w/ AI?)
// - MealPlan (Groceries)
// - Discover/AI Ideas
// - Groceries (if enabled as tab)
// - Settings
