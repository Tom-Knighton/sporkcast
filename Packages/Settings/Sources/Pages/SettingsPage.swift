//
//  SettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import Foundation
import Design
import Environment
import API

public struct SettingsPage: View {

    @Environment(AppRouter.self) private var appRouter
    @Environment(\.appSettings) private var appSettings
    @Environment(\.proAccess) private var proAccess
    @Environment(\.flagKit) private var flagKit
    @State private var repository = SettingsRepository()
    @State private var shareItems: [Any] = []
    @State private var cleanupURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    public init() {}

    public var body: some View {
        List {
            Section {
                NavigationLink(destination: GeneralSettingsPage()) {
                    Label("General", systemImage: "gearshape.fill")
                }

                NavigationLink(destination: RecipesSettingsPage()) {
                    Label("Recipes", systemImage: "book.closed.fill")
                }
            }

            Section {
                Button(action: openHomeSettings) {
                    Label("Home", systemImage: "house.fill")
                }
            }

            proSection

            #if DEBUG
            debugSection
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .sheet(isPresented: $isShareSheetPresented, onDismiss: cleanupSharedArtifacts) {
            ShareSheet(items: shareItems)
        }
        .alert("Error", isPresented: $isErrorPresented, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
        .task {
            await proAccess.refresh()
        }
    }

    private var proSection: some View {
        Section {
            if proAccess.hasProAccess {
                Label("Sporkast Pro Active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(proAccess.availablePlans) { plan in
                    Button(action: { purchase(plan) }) {
                        HStack {
                            Label(plan.title, systemImage: icon(for: plan.duration))
                            Spacer()
                            Text(plan.price)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(proAccess.isLoading)
                }

                Button(action: restorePurchases) {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
                .disabled(proAccess.isLoading)
            }

            if proAccess.isLoading {
                ProgressView()
            }
        } header: {
            Text("Sporkast Pro")
        } footer: {
            Text("Unlock recipe folders, nested folder browsing, and professional recipe tagging.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            NavigationLink(destination: DatabaseDebugViewerPage()) {
                Label("Database Viewer", systemImage: "internaldrive")
            }

            Button(role: .destructive, action: deleteAllData) {
                Text("Delete All DB")
            }

            Button(action: exportDatabase) {
                Text("Export DB")
            }

            Toggle("Recipe Folders & Tags Pro", isOn: appSettings.binding(\.enableRecipeOrganizationPro))
        }
    }
    #endif

    private func openHomeSettings() {
        appRouter.presentSheet(.householdSettings)
    }

    private func exportDatabase() {
        Task {
            do {
                let url = try await repository.exportDatabase()
                presentShareSheet(items: [url], cleanupURLs: [url])
            } catch {
                presentError(error)
            }
        }
    }

    private func deleteAllData() {
        Task {
            do {
                try await repository.deleteAllData()
            } catch {
                presentError(error)
            }
        }
    }

    private func purchase(_ plan: ProPlan) {
        Task {
            await proAccess.purchase(plan: plan)
            flagKit.updateSubscriptionTier(proAccess.subscriptionTier)
            if let message = proAccess.errorMessage {
                presentErrorMessage(message)
            }
        }
    }

    private func restorePurchases() {
        Task {
            await proAccess.restorePurchases()
            flagKit.updateSubscriptionTier(proAccess.subscriptionTier)
            if let message = proAccess.errorMessage {
                presentErrorMessage(message)
            }
        }
    }

    private func icon(for duration: ProPlanDuration) -> String {
        switch duration {
        case .monthly: return "calendar"
        case .yearly: return "calendar.badge.clock"
        case .lifetime: return "infinity"
        case .other: return "sparkles"
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

    private func presentError(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isErrorPresented = true
    }

    private func presentErrorMessage(_ message: String) {
        errorMessage = message
        isErrorPresented = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()

    NavigationStack {
        SettingsPage()
    }
    .environment(AppRouter(initialTab: .settings))
    .environment(\.homeServices, HouseholdService.shared)
    .environment(\.appSettings, SettingsStore())
    .environment(\.cloudKit, MockCloudKitGate())
    .environment(\.networkClient, APIClient(host: "https://api.dev.sporkast.tomk.online/"))
}
