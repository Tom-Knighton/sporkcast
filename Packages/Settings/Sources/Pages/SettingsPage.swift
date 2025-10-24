//
//  SettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import Design
import Environment

public struct SettingsPage: View {
    
    @Environment(AppRouter.self) private var appRouter
    
    public init() {}
    
    public var body: some View {
        List {
            Section {
                NavigationLink(destination: GeneralSettingsPage()) {
                    Label("General", systemImage: "gearshape.fill")
                }
            }
            
            Section {
                Button(action: { appRouter.presentSheet(.householdSettings) }) {
                    NavigationLink(destination: HouseholdSettingsPage()) {
                        Label("Home", systemImage: "house.fill")
                    }
                }
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
