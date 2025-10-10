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
                case let .recipe(id):
                    RecipePage(recipeId: id)
                        .navigationTransition(.zoom(
                            sourceID: "zoom-\(id.uuidString)",
                            in: namespace
                        ))
                case .recipes:
                    RecipeListPage()
                }
            }
    }
}
