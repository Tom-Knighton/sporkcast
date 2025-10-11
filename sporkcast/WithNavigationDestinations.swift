//
//  WithNavigationDestinations.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
import Recipe
import RecipesList
import Environment
import API

struct WithNavigationDestinations<Content: View>: View {
    let namespace: Namespace.ID
    let content: () -> Content

    init(namespace: Namespace.ID, @ViewBuilder content: @escaping () -> Content) {
        self.namespace = namespace
        self.content = content
    }

    var body: some View {
        content()
            .navigationDestination(for: AppDestination.self) { dest in
                switch dest {
                
                case .recipes:
                    RecipeListPage()
                case let .recipe(recipe):
                    RecipePage(recipe)
                        .navigationTransition(.zoom(
                            sourceID: "zoom-\(recipe.id.uuidString)",
                            in: namespace
                        ))
                case let .recipeFromId(id):
                    RecipePage(recipeId: id)
                        .navigationTransition(.zoom(
                            sourceID: "zoom-\(id.uuidString)",
                            in: namespace
                        ))
                }
            }
    }
}
