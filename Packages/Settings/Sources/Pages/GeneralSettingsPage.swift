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
    @Environment(\.proAccess) private var proAccess

    private var visibleTabs: [AppTab] {
        AppTab.allCases.filter { tab in
            tab != .discovery || flagKit.isEnabled(.recipeDiscoverySeparateTab, default: false)
        }
    }

    private var hasMealplanWeatherAccess: Bool {
        flagKit.isEnabled(.mealplanWeatherPro, default: proAccess.hasProAccess)
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

            Section("Import Features") {
                Toggle("Enable Web Selection Import", isOn: store.binding(\.enableWebSelectionImport))
                Toggle("Enable OCR Import", isOn: store.binding(\.enableOcrImport))
            }

            if hasMealplanWeatherAccess {
                Section("Mealplan") {
                    Toggle("Show Weather", isOn: store.binding(\.showMealplanWeather))
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
        guard store.settings.preferredLaunchTab == .discovery,
              !flagKit.isEnabled(.recipeDiscoverySeparateTab, default: false) else {
            return
        }

        store.update { settings in
            settings.preferredLaunchTab = .recipes
        }
    }
}
