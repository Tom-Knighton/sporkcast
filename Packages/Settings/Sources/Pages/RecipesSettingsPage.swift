//
//  RecipesSettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 04/04/2026.
//

import SwiftUI
import Foundation
import Design
import Environment

struct RecipesSettingsPage: View {

    @Environment(\.appSettings) private var store

    @State private var repository = SettingsRepository()
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var cleanupURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false
    @State private var isExportFormatDialogPresented = false
    @State private var isDeleteAllRecipesDialogPresented = false
    @State private var isDeletingAllRecipes = false

    var body: some View {
        List {
            SwiftUI.Section {
                Toggle("Show Ingredient Emojis", isOn: store.binding(\.showIngredientEmojis))
            } footer: {
                Text("Ingredient emojis only appear after they have been generated on a device that supports Apple Intelligence, or by someone in the same household using an Apple Intelligence device.")
            }

            SwiftUI.Section {
                Button(action: presentExportOptions) {
                    HStack(spacing: 12) {
                        Label("Export All Recipes", systemImage: "square.and.arrow.up")

                        Spacer()

                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isExporting)
            } header: {
                Text("Export")
            } footer: {
                Text("This will generate a ZIP file containing all of your exported recipes.")
            }

            SwiftUI.Section {
                Button(role: .destructive, action: presentDeleteAllRecipesConfirmation) {
                    HStack(spacing: 12) {
                        Label("Delete All Recipes", systemImage: "trash")

                        Spacer()

                        if isDeletingAllRecipes {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isDeletingAllRecipes)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This removes every recipe and its recipe-linked data from this device and iCloud sync.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recipes")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .confirmationDialog(
            "Choose Export Type",
            isPresented: $isExportFormatDialogPresented,
            titleVisibility: .visible
        ) {
            ForEach(RecipeExportFormat.allCases) { format in
                Button(format.title) {
                    startExport(as: format)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will generate a ZIP file containing all of your exported recipes.\n\n"
                + "Sporkast Backup: Best for importing back into Sporkast.\n"
                + "Markdown: Exports each recipe as a RecipeMD markdown file."
            )
        }
        .confirmationDialog(
            "Delete All Recipes?",
            isPresented: $isDeleteAllRecipesDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Delete All Recipes", role: .destructive, action: deleteAllRecipes)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Export your recipes first if you may need them later.")
        }
        .sheet(isPresented: $isShareSheetPresented, onDismiss: cleanupSharedArtifacts) {
            ExportShareSheet(items: shareItems)
        }
        .alert("Recipes Action Failed", isPresented: $isErrorPresented, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
    }

    private func presentExportOptions() {
        guard !isExporting else { return }
        isExportFormatDialogPresented = true
    }

    private func presentDeleteAllRecipesConfirmation() {
        guard !isDeletingAllRecipes else { return }
        isDeleteAllRecipesDialogPresented = true
    }

    private func startExport(as format: RecipeExportFormat) {
        guard !isExporting else { return }
        isExporting = true

        Task {
            defer { isExporting = false }

            do {
                let exportPackage = try await repository.exportRecipes(as: format)
                shareItems = [exportPackage.archiveURL]
                cleanupURLs = exportPackage.cleanupURLs
                isShareSheetPresented = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isErrorPresented = true
            }
        }
    }

    private func cleanupSharedArtifacts() {
        let fileManager = FileManager.default
        for url in cleanupURLs {
            try? fileManager.removeItem(at: url)
        }
        cleanupURLs = []
        shareItems = []
    }

    private func deleteAllRecipes() {
        guard !isDeletingAllRecipes else { return }
        isDeletingAllRecipes = true

        Task {
            defer { isDeletingAllRecipes = false }

            do {
                try await repository.deleteAllRecipes()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isErrorPresented = true
            }
        }
    }
}

private struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()

    NavigationStack {
        RecipesSettingsPage()
    }
}
