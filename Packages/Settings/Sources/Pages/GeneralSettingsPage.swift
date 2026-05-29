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
    @State private var repository = SettingsRepository()
    @State private var shareItems: [Any] = []
    @State private var cleanupURLs: [URL] = []
    @State private var isShareSheetPresented = false
    
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
            
            Section("Getting Started") {
                Button(action: showOnboarding) {
                    Label("Show Onboarding", systemImage: "sparkles.rectangle.stack.fill")
                }
            }

            if flagKit.isEnabled(.recipeDiagnosticsExport, default: false) {
                Section("Diagnostics") {
                    Button(action: exportRecipeDebugLogs) {
                        Label("Export Recipe Debug Logs", systemImage: "doc.text")
                    }
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("General")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .onAppear(perform: normalizePreferredLaunchTab)
        .sheet(isPresented: $isShareSheetPresented, onDismiss: cleanupSharedArtifacts) {
            ShareSheet(items: shareItems)
        }
    }

    private func normalizePreferredLaunchTab() {
        guard !visibleTabs.contains(store.settings.preferredLaunchTab) else { return }

        store.update { settings in
            settings.preferredLaunchTab = .recipes
        }
    }
    
    private func exportRecipeDebugLogs() {
        Task {
            do {
                let url = try await repository.exportRecipeDebugLogs()
                presentShareSheet(items: [url], cleanupURLs: [url])
            } catch {
                print(error)
            }
        }
    }

    private func showOnboarding() {
        store.update { settings in
            settings.hasCompletedOnboarding = false
        }
    }
    
    private func presentShareSheet(items: [Any], cleanupURLs: [URL]) {
        shareItems = items
        self.cleanupURLs = cleanupURLs
        isShareSheetPresented = true
    }
    
    private func cleanupSharedArtifacts() {
        let fileManager = FileManager.default
        for url in cleanupURLs {
            try? fileManager.removeItem(at: url)
        }
        cleanupURLs = []
        shareItems = []
    }

}
