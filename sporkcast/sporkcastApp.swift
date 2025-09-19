//
//  sporkcastApp.swift
//  sporkcast
//
//  Created by Tom Knighton on 22/08/2025.
//

import SwiftUI
import Recipe
import Design
import API
import Environment
internal import AppRouter

@main
struct sporkcastApp: App {
    
    @State private var appRouter: AppRouter = AppRouter(initialTab: .recipes)
    
    var body: some Scene {
        WindowGroup {
            TabView {
                ForEach(AppTab.allCases) { tab in
                    Tab(tab.title, systemImage: tab.icon) {
                        NavigationStack(path: $appRouter[tab]) {
                            switch tab {
                            case .recipes:
                                RecipePage()
                            case .testRecipe:
                                RecipePage()
                            }
                        }
                    }
                }
            }
            .environment(appRouter)
            .environment(\.networkClient, APIClient(host: "https://api.dev.recipe.tomk.online/"))
        }
    }
}
