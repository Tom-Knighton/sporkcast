//
//  TabScaffold.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
internal import AppRouter
import Environment

struct TabScaffold<Recipes: View, Discovery: View, Mealplans: View, ShoppingLists: View, Settings: View>: View {
    let recipes: () -> Recipes
    let discovery: () -> Discovery
    let mealplans: () -> Mealplans
    let shoppingLists: () -> ShoppingLists
    let settings: () -> Settings
    let isDiscoveryTabEnabled: Bool
    @Binding var selection: AppTab
    

    init(
        selection: Binding<AppTab>,
        isDiscoveryTabEnabled: Bool,
        @ViewBuilder recipes: @escaping () -> Recipes,
        @ViewBuilder discovery: @escaping () -> Discovery,
        @ViewBuilder mealplans: @escaping () -> Mealplans,
        @ViewBuilder shoppingLists: @escaping () -> ShoppingLists,
        @ViewBuilder settings: @escaping () -> Settings,
    ) {
        self.recipes = recipes
        self.discovery = discovery
        self.mealplans = mealplans
        self.shoppingLists = shoppingLists
        self.settings = settings
        self.isDiscoveryTabEnabled = isDiscoveryTabEnabled
        self._selection = selection
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.recipes) {
                recipes()
            } label: {
                Label(AppTab.recipes.title, systemImage: AppTab.recipes.icon)
            }

            if isDiscoveryTabEnabled {
                Tab(value: AppTab.discovery) {
                    discovery()
                } label: {
                    Label(AppTab.discovery.title, systemImage: AppTab.discovery.icon)
                }
            }
            
            Tab(value: AppTab.mealplan) {
                mealplans()
            } label: {
                Label(AppTab.mealplan.title, systemImage: AppTab.mealplan.icon)
            }
            
            Tab(value: AppTab.shoppingLists) {
                shoppingLists()
            } label: {
                Label(AppTab.shoppingLists.title, systemImage: AppTab.shoppingLists.icon)
            }
        
            Tab(value: AppTab.settings) {
                settings()
            } label: {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
        }
    }
}
