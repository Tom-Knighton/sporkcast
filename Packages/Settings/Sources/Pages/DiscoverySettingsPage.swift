//
//  DiscoverySettingsPage.swift
//  Settings
//

import Design
import Environment
import SwiftUI

struct DiscoverySettingsPage: View {
    @Environment(\.appSettings) private var store

    var body: some View {
        List {
            Section {
                Toggle("Show Discovery", isOn: store.binding(\.showDiscoveryPage))
            } footer: {
                Text("When hidden, discovery is removed from the tab bar and recipe list toolbar.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Discovery")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
    }
}
