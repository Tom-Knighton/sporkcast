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
                Text("This removes every recipe and related recipe data from this device and any shared homes.")
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
            Text(errorMessage ?? "We couldn't finish that recipe action. Please try again.")
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
                errorMessage = exportErrorMessage(for: error)
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
                errorMessage = CustomerFacingErrorMessage.message(
                    for: error,
                    fallback: "We couldn't delete your recipes right now. Please try again."
                )
                isErrorPresented = true
            }
        }
    }

    private func exportErrorMessage(for error: Error) -> String {
        if let exportError = error as? RecipeExportError {
            switch exportError {
            case .noRecipesAvailable:
                return "No recipes are available to export."
            case .failedToEncodeRecipe:
                return "We couldn't prepare one of your recipes for export. Please try again."
            case .failedToCreateArchive:
                return "We couldn't create the export file. Please try again."
            }
        }

        return CustomerFacingErrorMessage.message(
            for: error,
            fallback: "We couldn't export your recipes right now. Please try again."
        )
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
