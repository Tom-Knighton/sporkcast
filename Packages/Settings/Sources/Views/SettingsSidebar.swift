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

struct SettingsSidebar: View {

    @Binding var selection: SettingsDestination?

    @Environment(AppRouter.self) private var appRouter
    @State private var repository = SettingsRepository()
    @State private var shareItems: [Any] = []
    @State private var cleanupURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    var body: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: SettingsDestination.general) {
                    Label("General", systemImage: "gearshape.fill")
                }

                NavigationLink(value: SettingsDestination.recipes) {
                    Label("Recipes", systemImage: "book.closed.fill")
                }

                NavigationLink(value: SettingsDestination.mealplan) {
                    Label("Mealplan", systemImage: "calendar")
                }

                NavigationLink(value: SettingsDestination.discovery) {
                    Label("Discovery", systemImage: "sparkles")
                }

                NavigationLink(value: SettingsDestination.groceries) {
                    Label("Groceries", systemImage: "cart")
                }

                NavigationLink(value: SettingsDestination.weather) {
                    Label("Weather", systemImage: "cloud.sun.fill")
                }
            }

            Section {
                Button(action: openHomeSettings) {
                    Label("Home", systemImage: "house.fill")
                }

                NavigationLink(value: SettingsDestination.pro) {
                    Label("Sporkast Pro", systemImage: "sparkles")
                }
            }

            Section {
                Link(destination: Self.helpURL) {
                    Label("Help", systemImage: "questionmark.circle")
                }

                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }

            #if DEBUG
            debugSection
            #endif

            footerSection
        }
        .modifier(RecipeNavigationBarBehavior())
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .sheet(isPresented: $isShareSheetPresented, onDismiss: cleanupSharedArtifacts) {
            ShareSheet(items: shareItems)
        }
        .alert("Settings Unavailable", isPresented: $isErrorPresented, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "We couldn't finish that settings action. Please try again.")
        })
    }

    private var footerSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Tom Knighton - v\(Self.appVersion)")
                        .font(.footnote)

                    Text("Device ID: \(Self.deviceID)")
                        .font(.caption2)
                        .textSelection(.enabled)
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .combine)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            NavigationLink(value: SettingsDestination.database) {
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
        errorMessage = CustomerFacingErrorMessage.message(
            for: error,
            fallback: "We couldn't finish that settings action. Please try again."
        )
        isErrorPresented = true
    }

    private static let helpURL = URL(string: "https://sporkast.tom-knighton.com/help")!
    private static let privacyPolicyURL = URL(string: "https://sporkast.tom-knighton.com/privacy")!

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0.0"
    }

    private static var deviceID: String {
        InstallationId.get()
    }

}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RecipeNavigationBarBehavior: ViewModifier {
    func body(content: Content) -> some View {
#if compiler(>=6.4)
        if #available(iOS 27, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
#else
        content
#endif
    }
}
