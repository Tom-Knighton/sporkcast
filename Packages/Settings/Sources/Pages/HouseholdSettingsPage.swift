//
//  HouseholdSettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import API
import Design

public struct HouseholdSettingsPage: View {
    
    @Environment(HouseholdService.self) private var households
    @Environment(AlertManager.self) private var alerts
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var nameError: String? = nil
    @State private var showError: Bool = false
    
    public init() {}
    
    public var body: some View {
        @Bindable var alerts = alerts
        ZStack {
            Color.layer1.ignoresSafeArea()
            if households.canCreate {
                NoHouseholdsView()
            } else if let household = households.household {
                householdView(for: household)
            }
        }
        .task {
            self.name = households.household?.name ?? ""
        }
        .alert("Error", isPresented: $showError, actions: {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        }, message: {
            Text(nameError ?? "")
        })
    }
    
    @ViewBuilder private func householdView(for household: Household) -> some View {
        List {
            Section("Name") {
                TextField("Name:", text: $name)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .navigationTitle(household.name)
        .toolbar {
            ToolbarItem {
                Button(action: { self.dismiss() }) {
                    Text("Cancel")
                }
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button(action: { Task { await save() }}) {
                    Text("Save")
                        .bold()
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
        }
        .fontDesign(.rounded)
    }
    
    private func save() async {
        if name.count == 0 || name.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
            self.nameError = "Please enter a valid home name."
            self.showError = true
            return
        }
        
        await households.rename(to: name.trimmingCharacters(in: .whitespacesAndNewlines))
        self.dismiss()
    }
}
