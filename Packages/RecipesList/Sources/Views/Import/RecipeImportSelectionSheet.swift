//
//  RecipeImportSelectionSheet.swift
//  RecipesList
//
//  Created by Codex on 27/03/2026.
//

import SwiftUI
import RecipeImporting

struct RecipeImportSelectionSheet: View {
    let candidates: [RecipeImportCandidate]
    @Binding var selectedIDs: Set<UUID>
    let onImportSelected: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(candidates) { candidate in
                Button {
                    if selectedIDs.contains(candidate.id) {
                        selectedIDs.remove(candidate.id)
                    } else {
                        selectedIDs.insert(candidate.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.recipe.title)
                                .font(.headline)
                                .lineLimit(2)

                            Text("\(ingredientCount(for: candidate)) ingredients · \(stepCount(for: candidate)) steps")
                                 .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Quality: \(candidate.quality.level.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: selectedIDs.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIDs.contains(candidate.id) ? .green : .secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Recipes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImportSelected()
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private func ingredientCount(for candidate: RecipeImportCandidate) -> Int {
        candidate.recipe.ingredientSections.flatMap(\.ingredients).count
    }

    private func stepCount(for candidate: RecipeImportCandidate) -> Int {
        candidate.recipe.stepSections.flatMap(\.steps).count
    }
}
