//
//  HouseholdSettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import Models
import Design
import Environment

public struct HouseholdSettingsPage: View {
    
    @Environment(\.homeServices) private var households
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var nameError: String? = nil
    @State private var showError: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isPreparingSupabaseInvite: Bool = false
    
    @State private var supabaseInviteURL: URL?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()
            if households.canCreate {
                NoHouseholdsView()
            } else if let home = households.home {
                householdView(for: home)
                    .interactiveDismissDisabled()
            }
        }
        .task {
            self.name = households.home?.name ?? ""
        }
        .alert("Error", isPresented: $showError, actions: {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        }, message: {
            Text(nameError ?? "")
        })
        .alert("Confirm", isPresented: $showDeleteConfirmation, actions: {
            Button(role: .cancel, action: {}) {
                Text("Cancel")
            }
            Button(role: .destructive, action: {
                Task { [households] in  await households.leave(disbandIfOwner: true) }
            }) {
                Text("Leave Home")
            }
        }, message: {
            Text("Are you sure you want to leave this home? You'll keep a copy of any recipes, but new recipes and mealplans will no longer sync. You'll have to be reinvited if you wish to re-join this home.")
        })
    }
    
    @ViewBuilder private func householdView(for household: Home) -> some View {
        List {
            Section("Name") {
                TextField("Name:", text: $name)
            }
            
            Section("Members") {
                
                ForEach(households.residents) { resident in
                    Text(resident.name)
                }
                
                Button {
                    Task { await prepareSupabaseInvite() }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(isPreparingSupabaseInvite ? "Preparing Invite" : "Invite to Home", systemImage: "plus")
                            .bold()
                        Text("Invite a friend or family member to your home and share recipes, mealplans and more.")
                            .font(.subheadline)
                            .tint(.gray)
                    }
                }
                .disabled(isPreparingSupabaseInvite)
                
            }
            
            Section("Danger") {
                Button(role: .destructive) {
                    self.showDeleteConfirmation = true
                } label: {
                    Text("Leave Home")
                }
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
        .sheet(item: Binding(
            get: { supabaseInviteURL.map(IdentifiableURL.init(url:)) },
            set: { supabaseInviteURL = $0?.url }
        )) { invite in
            ActivityView(activityItems: [invite.url])
        }
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

    private func prepareSupabaseInvite() async {
        guard !isPreparingSupabaseInvite else { return }
        isPreparingSupabaseInvite = true
        defer { isPreparingSupabaseInvite = false }

        do {
            guard let url = try await households.createSupabaseInviteLink() else {
                nameError = "Supabase sync is not available for this home yet."
                showError = true
                return
            }
            supabaseInviteURL = url
        } catch {
            nameError = error.localizedDescription
            showError = true
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL

    var id: String { url.absoluteString }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }
    
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
        // no-op
    }
}

#Preview {
    
    let _ = PreviewSupport.preparePreviewDatabase()
    NavigationStack {
        HouseholdSettingsPage()
    }
    .environment(\.homeServices, MockHouseholdService(withHome: true))
    .environment(AlertManager())
}
