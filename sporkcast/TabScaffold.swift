//
//  TabScaffold.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
internal import AppRouter
import Environment

struct TabScaffold<Recipes: View, Mealplans: View, Settings: View>: View {
    let recipes: () -> Recipes
    let mealplans: () -> Mealplans
    let settings: () -> Settings
    @Binding var selection: AppTab

    init(
        selection: Binding<AppTab>,
        @ViewBuilder recipes: @escaping () -> Recipes,
        @ViewBuilder mealplans: @escaping () -> Mealplans,
        @ViewBuilder settings: @escaping () -> Settings,
    ) {
        self.recipes = recipes
        self.mealplans = mealplans
        self.settings = settings
        self._selection = selection
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.recipes) {
                recipes()
            } label: {
                Label(AppTab.recipes.title, systemImage: AppTab.recipes.icon)
            }
            
            Tab(value: AppTab.mealplan) {
                mealplans()
            } label: {
                Label(AppTab.mealplan.title, systemImage: AppTab.mealplan.icon)
            }
        
            Tab(value: AppTab.settings) {
                settings()
            } label: {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
        }
    }
}
