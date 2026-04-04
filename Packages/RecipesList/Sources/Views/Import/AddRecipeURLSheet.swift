//
//  AddRecipeURLSheet.swift
//  RecipesList
//
//  Created by Tom Knighton on 27/03/2026.
//

import SwiftUI

struct AddRecipeURLSheet: View {
    @Binding var urlText: String
    let onAdd: () -> Bool

    @Environment(\.dismiss) private var dismiss

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Paste a recipe link to add it directly.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("https://", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .modifier(InteractiveGlassCard(cornerRadius: 12))
                    .accessibilityLabel("Recipe URL")

                Button {
                    if onAdd() {
                        dismiss()
                    }
                } label: {
                    Text("Add Recipe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(trimmedURL.isEmpty)
                .accessibilityLabel("Add recipe from URL")
            }
            .padding(16)
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct InteractiveGlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    }
}
