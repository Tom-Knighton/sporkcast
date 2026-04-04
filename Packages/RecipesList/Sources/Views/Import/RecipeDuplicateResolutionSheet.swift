//
//  RecipeDuplicateResolutionSheet.swift
//  RecipesList
//
//  Created by Tom Knighton on 27/03/2026.
//

import SwiftUI
import RecipeImporting

struct RecipeDuplicateResolutionSheet: View {
    let candidates: [RecipeImportCandidate]
    let duplicates: [UUID: DuplicateMatch]
    let onConfirm: ([UUID: DuplicateResolutionDecision]) -> Void

    @State private var resolutions: [UUID: DuplicateResolution] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(duplicateCandidates) { candidate in
                if let duplicate = duplicates[candidate.id] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(candidate.recipe.title)
                            .font(.headline)

                        Text("Possible duplicate: \(duplicate.existingTitle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(duplicate.reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker("Resolution", selection: resolutionBinding(for: candidate.id)) {
                            ForEach(DuplicateResolution.allCases) { resolution in
                                Text(resolution.title).tag(resolution)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Resolve Duplicates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onConfirm(resolutionDecisions())
                        dismiss()
                    }
                }
            }
        }
    }

    private var duplicateCandidates: [RecipeImportCandidate] {
        candidates.filter { duplicates[$0.id] != nil }
    }

    private func resolutionBinding(for candidateID: UUID) -> Binding<DuplicateResolution> {
        Binding(
            get: { resolutions[candidateID] ?? .keepBoth },
            set: { resolutions[candidateID] = $0 }
        )
    }

    private func resolutionDecisions() -> [UUID: DuplicateResolutionDecision] {
        var output: [UUID: DuplicateResolutionDecision] = [:]

        for candidate in duplicateCandidates {
            let resolution = resolutions[candidate.id] ?? .keepBoth
            let existingId = duplicates[candidate.id]?.existingRecipeID
            output[candidate.id] = DuplicateResolutionDecision(candidateID: candidate.id, resolution: resolution, existingRecipeID: existingId)
        }

        return output
    }
}
