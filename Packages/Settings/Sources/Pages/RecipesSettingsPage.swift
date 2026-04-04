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

    @State private var repository = SettingsRepository()
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var cleanupURLs: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var exportErrorMessage: String?
    @State private var isExportErrorPresented = false

    var body: some View {
        List {
            SwiftUI.Section {
                Button(action: startExport) {
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recipes")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .sheet(isPresented: $isShareSheetPresented, onDismiss: cleanupSharedArtifacts) {
            ExportShareSheet(items: shareItems)
        }
        .alert("Export Failed", isPresented: $isExportErrorPresented, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(exportErrorMessage ?? "An unknown error occurred.")
        })
    }

    private func startExport() {
        guard !isExporting else { return }
        isExporting = true

        Task {
            defer { isExporting = false }

            do {
                let exportPackage = try await repository.exportRecipes(as: .sporkast)
                shareItems = [exportPackage.archiveURL]
                cleanupURLs = exportPackage.cleanupURLs
                isShareSheetPresented = true
            } catch {
                exportErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isExportErrorPresented = true
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
