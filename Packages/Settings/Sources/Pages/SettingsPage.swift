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
