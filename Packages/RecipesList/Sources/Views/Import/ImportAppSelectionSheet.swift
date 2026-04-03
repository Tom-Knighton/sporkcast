//
//  ImportAppSelectionSheet.swift
//  RecipesList
//
//  Created by Codex on 01/04/2026.
//

import SwiftUI

struct ImportAppSelectionSheet: View {
    let onSelect: (ImportAppSource) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.flagKit) private var flagKit
    
    private var appSources: [ImportAppSource] {
        var sources = ImportAppSource.allCases
        if !flagKit.isEnabled(.recipeImportPaprikaEnabled, default: false) {
            sources.removeAll(where: { $0.id == "paprika" })
        }
        return sources
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose the app you exported from to apply the right file format and parser.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    GlassEffectContainer(spacing: 10) {
                        sourceCards
                    }
                }
                .padding(16)
            }
            .navigationTitle("Import Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var sourceCards: some View {
        VStack(spacing: 10) {
            ForEach(appSources) { source in
                Button {
                    onSelect(source)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: source.icon)
                            .font(.title3.weight(.semibold))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(source.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .modifier(ImportSourceCardStyle())
            }
        }
    }
}

private struct ImportSourceCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}
