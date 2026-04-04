//
//  MarkdownImportSheet.swift
//  RecipesList
//
//  Created by Tom Knighton on 27/03/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct MarkdownImportSheet: View {
    @Binding var text: String
    let onImport: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isFileImporterPresented = false
    @State private var loadErrorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Paste markdown containing ingredients and steps. Flexible formats are supported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Load Markdown File", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .navigationTitle("Import Markdown")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.markdownText, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }
                    let hasAccess = fileURL.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            fileURL.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        text = try String(contentsOf: fileURL, encoding: .utf8)
                        loadErrorMessage = nil
                    } catch {
                        loadErrorMessage = "Could not read that markdown file."
                    }
                case .failure:
                    loadErrorMessage = "Could not open that markdown file."
                }
            }
        }
    }
}

private extension UTType {
    static var markdownText: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }
}
