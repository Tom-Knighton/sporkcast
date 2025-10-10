//
//  TabScaffold.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
internal import AppRouter
import Environment

struct TabScaffold<Recipes: View, TestRecipe: View>: View {
    let recipes: () -> Recipes
    let testRecipe: () -> TestRecipe

    init(
        @ViewBuilder recipes: @escaping () -> Recipes,
        @ViewBuilder testRecipe: @escaping () -> TestRecipe
    ) {
        self.recipes = recipes
        self.testRecipe = testRecipe
    }

    var body: some View {
        TabView {
            Tab(AppTab.recipes.title, systemImage: AppTab.recipes.icon) {
                recipes()
            }
            Tab(AppTab.testRecipe.title, systemImage: AppTab.testRecipe.icon) {
                testRecipe()
            }
        }
    }
}
