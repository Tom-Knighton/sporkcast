//
//  AddRecipeSheet.swift
//  RecipesList
//
//  Created by Codex on 27/03/2026.
//

import SwiftUI

enum AddRecipeAction: String, Identifiable, CaseIterable {
    case webURL
    case fileArchive
    case markdown
    case webSelection
    case photoOCR

    var id: String { rawValue }

    var title: String {
        switch self {
        case .webURL:
            return "From web URL"
        case .fileArchive:
            return "From app export"
        case .markdown:
            return "From markdown"
        case .webSelection:
            return "From web selection"
        case .photoOCR:
            return "From photo/OCR"
        }
    }

    var subtitle: String {
        switch self {
        case .webURL:
            return "Add directly from a recipe link."
        case .fileArchive:
            return "Choose Pestle, Crouton, or Paprika imports."
        case .markdown:
            return "Import recipe text written in markdown."
        case .webSelection:
            return "Import highlighted text copied from a site."
        case .photoOCR:
            return "Import from a camera scan or photo OCR text."
        }
    }

    var icon: String {
        switch self {
        case .webURL:
            return "link"
        case .fileArchive:
            return "doc.zipper"
        case .markdown:
            return "doc.plaintext"
        case .webSelection:
            return "highlighter"
        case .photoOCR:
            return "camera.viewfinder"
        }
    }

    var isImportAction: Bool {
        switch self {
        case .webURL:
            return false
        case .fileArchive, .markdown, .webSelection, .photoOCR:
            return true
        }
    }
}

struct AddRecipeSheet: View {
    let options: [AddRecipeAction]
    let onSelect: (AddRecipeAction) -> Void

    @Environment(\.dismiss) private var dismiss

    private var addOptions: [AddRecipeAction] {
        options.filter { !$0.isImportAction }
    }

    private var importOptions: [AddRecipeAction] {
        options.filter(\.isImportAction)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !addOptions.isEmpty {
                        Text("Add")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        optionStack(addOptions)
                    }

                    if !importOptions.isEmpty {
                        Text("Import")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, addOptions.isEmpty ? 0 : 6)

                        optionStack(importOptions)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func optionStack(_ items: [AddRecipeAction]) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                optionCards(items)
            }
        } else {
            optionCards(items)
        }
    }

    @ViewBuilder
    private func optionCards(_ items: [AddRecipeAction]) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { action in
                Button {
                    onSelect(action)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.icon)
                            .font(.title3.weight(.semibold))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(action.subtitle)
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
                .modifier(InteractiveGlassCard())
            }
        }
    }
}

private struct InteractiveGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
