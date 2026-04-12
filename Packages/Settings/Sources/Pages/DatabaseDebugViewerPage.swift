//
//  DatabaseDebugViewerPage.swift
//  Settings
//
//  Created by Tom Knighton on 09/04/2026.
//

#if DEBUG
import SwiftUI
import UIKit
import Design
import Environment

struct DatabaseDebugViewerPage: View {

    @State private var repository = SettingsRepository()
    @State private var dump: DebugDatabaseDump?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        Group {
            if isLoading && dump == nil {
                ProgressView("Loading Database...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let dump {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generated: \(dump.generatedAt.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(dump.content.isEmpty ? "No table content found." : dump.content)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("No Data Loaded", systemImage: "internaldrive")
            }
        }
        .navigationTitle("Database Viewer")
        .background(Color.layer1)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: refresh) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)

                if let content = dump?.content, !content.isEmpty {
                    Button(action: { UIPasteboard.general.string = content }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .task {
            guard dump == nil else { return }
            await reload()
        }
        .alert("Error", isPresented: $isShowingError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
    }

    private func refresh() {
        Task { await reload() }
    }

    @MainActor
    private func reload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            dump = try await repository.exportDebugDatabaseDump()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isShowingError = true
        }
    }
}
#endif
