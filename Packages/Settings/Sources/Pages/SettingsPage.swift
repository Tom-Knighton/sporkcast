//
//  SettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import Design

public struct SettingsPage: View {
    
    public init() {}
    
    public var body: some View {
        List {
            NavigationLink(destination: GeneralSettingsPage()) {
                Label("General", systemImage: "gearshape.fill")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
    }
}

#Preview {
    NavigationStack {
        SettingsPage()
    }
}
