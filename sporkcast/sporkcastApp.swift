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
import RecipesList
internal import AppRouter
import SwiftData

@main
struct sporkcastApp: App {
    
    @Namespace private var appRouterNamespace
    @State private var appRouter: AppRouter = AppRouter(initialTab: .recipes)
    
    var body: some Scene {
        WindowGroup {
            TabView {
                ForEach(AppTab.allCases) { tab in
                    Tab(tab.title, systemImage: tab.icon) {
                        NavigationStack(path: $appRouter[tab]) {
                            switch tab {
                            case .recipes:
                                withPaths {
                                    RecipeListPage()
                                }
                            case .testRecipe:
                                withPaths {
                                    RecipePage()
                                }
                            }
                        }
                    }
                }
            }
            .environment(appRouter)
            .environment(\.networkClient, APIClient(host: "https://api.dev.recipe.tomk.online/"))
            .environment(ZoomManager(appRouterNamespace))
            .modelContainer(V1Models.sharedContainer!)
            .tabBarMinimizeBehavior(.onScrollDown)
            .tint(.white)
        }
    }
    
    @ViewBuilder
    private func withPaths<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .navigationDestination(for: AppDestination.self) { dest in
                switch dest {
                case let .recipe(id):
                    RecipePage(recipeId: id)
                        .navigationTransition(.zoom(sourceID: "zoom-\(id.uuidString)", in: appRouterNamespace))
                case .recipes:
                    RecipeListPage()
                }
            }
    }
}
