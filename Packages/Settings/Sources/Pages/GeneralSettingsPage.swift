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
    
    var body: some View {

        List {
            Section("App") {
                Picker("Theme", selection: store.binding(\.theme)) {
                    ForEach(AppSettings.Theme.allCases) { theme in
                        Text(String(describing: theme).capitalized).tag(theme)
                    }
                }
                Picker("Default Tab", selection: store.binding(\.preferredLaunchTab)) {
                    ForEach(AppTab.allCases, id: \.self) {
                        Text(String(describing: $0).capitalized).tag($0)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("General")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
    }
}
