//
//  GeneralSettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import Design
import SwiftUI
import Environment

struct GeneralSettingsPage: View {
    
    @Environment(\.appSettings) private var store
    @Environment(\.flagKit) private var flagKit

    private var visibleTabs: [AppTab] {
        AppTab.allCases.filter { tab in
            switch tab {
            case .discovery:
                return store.settings.showDiscoveryPage && flagKit.isEnabled(.recipeDiscoverySeparateTab, default: false)
            case .mealplan:
                return store.settings.showMealplanPage
            case .shoppingLists:
                return store.settings.showGroceriesPage
            case .recipes, .settings:
                return true
            }
        }
    }

    var body: some View {

        List {
            Section("App") {
                Picker("Theme", selection: store.binding(\.theme)) {
                    ForEach(AppSettings.Theme.allCases) { theme in
                        Text(String(describing: theme).capitalized).tag(theme)
                    }
                }
                Picker("Default Tab", selection: store.binding(\.preferredLaunchTab)) {
                    ForEach(visibleTabs, id: \.self) {
                        Text(String(describing: $0).capitalized).tag($0)
                    }
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("General")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .onAppear(perform: normalizePreferredLaunchTab)
    }

    private func normalizePreferredLaunchTab() {
        guard !visibleTabs.contains(store.settings.preferredLaunchTab) else { return }

        store.update { settings in
            settings.preferredLaunchTab = .recipes
        }
    }
}
