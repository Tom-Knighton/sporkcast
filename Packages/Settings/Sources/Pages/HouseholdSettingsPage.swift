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
    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isPreparingInvite: Bool = false
    
    @State private var inviteURL: URL?
    
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
        .alert("Home Unavailable", isPresented: $showError, actions: {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        }, message: {
            Text(errorMessage ?? "We couldn't update your home right now. Please try again.")
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
                    Task { await prepareInvite() }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(isPreparingInvite ? "Preparing Invite" : "Invite to Home", systemImage: "plus")
                            .bold()
                        Text("Invite a friend or family member to your home and share recipes, mealplans and more.")
                            .font(.subheadline)
                            .tint(.gray)
                    }
                }
                .disabled(isPreparingInvite)
                
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
            get: { inviteURL.map(IdentifiableURL.init(url:)) },
            set: { inviteURL = $0?.url }
        )) { invite in
            ActivityView(activityItems: [invite.url])
        }
    }
    
    private func save() async {
        if name.count == 0 || name.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
            self.errorMessage = "Please enter a valid home name."
            self.showError = true
            return
        }
        
        await households.rename(to: name.trimmingCharacters(in: .whitespacesAndNewlines))
        self.dismiss()
    }

    private func prepareInvite() async {
        guard !isPreparingInvite else { return }
        isPreparingInvite = true
        defer { isPreparingInvite = false }

        do {
            guard let url = try await households.createSupabaseInviteLink() else {
                errorMessage = "Invites aren't available for this home yet. Please try again in a moment."
                showError = true
                return
            }
            inviteURL = url
        } catch {
            errorMessage = CustomerFacingErrorMessage.message(
                for: error,
                fallback: "We couldn't create an invite right now. Please try again."
            )
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
