//
//  RecipeImportPreviewEditSheet.swift
//  RecipesList
//
//  Created by Tom Knighton on 22/05/2026.
//

import SwiftUI
import Models
import RecipeImporting
#if canImport(UIKit)
import UIKit
#endif

struct RecipeImportPreviewEditSheet: View {

    let candidate: RecipeImportCandidate
    let onCancel: () -> Void
    let onSave: (RecipeImportCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var serves: String
    @State private var ingredientsText: String
    @State private var stepsText: String

    private var ingredientLines: [String] {
        lines(from: ingredientsText)
    }

    private var stepLines: [String] {
        lines(from: stepsText)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!ingredientLines.isEmpty || !stepLines.isEmpty)
    }

    init(
        candidate: RecipeImportCandidate,
        onCancel: @escaping () -> Void,
        onSave: @escaping (RecipeImportCandidate) -> Void
    ) {
        self.candidate = candidate
        self.onCancel = onCancel
        self.onSave = onSave
        self._title = State(initialValue: candidate.recipe.title)
        self._description = State(initialValue: candidate.recipe.description ?? "")
        self._serves = State(initialValue: candidate.recipe.serves ?? "")
        self._ingredientsText = State(initialValue: candidate.recipe.ingredientSections.flatMap { section in
            section.ingredients.map(\.ingredientText)
        }.joined(separator: "\n"))
        self._stepsText = State(initialValue: candidate.recipe.stepSections.flatMap { section in
            section.steps.map(\.instructionText)
        }.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasImagePreview {
                    Section {
                        imagePreview
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                Section("Recipe") {
                    TextField("Title", text: $title)
                    TextField("Serves", text: $serves)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text("\(ingredientLines.count) ingredients · \(stepLines.count) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Ingredients") {
                    TextEditor(text: $ingredientsText)
                        .font(.body)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Ingredients, one per line")
                }

                Section("Method") {
                    TextEditor(text: $stepsText)
                        .font(.body)
                        .frame(minHeight: 220)
                        .accessibilityLabel("Method steps, one per line")
                }
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var hasImagePreview: Bool {
        candidate.recipe.image.imageThumbnailData != nil || candidate.recipe.image.imageUrl != nil
    }

    @ViewBuilder
    private var imagePreview: some View {
        #if canImport(UIKit)
        if let data = candidate.recipe.image.imageThumbnailData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .accessibilityHidden(true)
        } else if let imageUrl = candidate.recipe.image.imageUrl,
                  let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.secondary.opacity(0.12)
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    Color.secondary.opacity(0.12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .accessibilityHidden(true)
        }
        #endif
    }

    private func cancel() {
        onCancel()
        dismiss()
    }

    private func save() {
        onSave(editedCandidate())
        dismiss()
    }

    private func editedCandidate() -> RecipeImportCandidate {
        var recipe = candidate.recipe
        recipe.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.description = description.nilIfBlank
        recipe.serves = serves.nilIfBlank
        recipe.ingredientSections = [editedIngredientSection(existing: recipe.ingredientSections.first)]
        recipe.stepSections = [editedStepSection(existing: recipe.stepSections.first)]
        recipe.dateModified = .now

        let rawText = ([recipe.title] + ingredientLines + stepLines).joined(separator: "\n")
        return RecipeImportCandidate(
            id: candidate.id,
            recipe: recipe,
            provenance: candidate.provenance,
            quality: .evaluate(recipe: recipe),
            usedAPIFallback: candidate.usedAPIFallback,
            rawTextForFallback: rawText
        )
    }

    private func editedIngredientSection(existing: RecipeIngredientGroup?) -> RecipeIngredientGroup {
        let existingIngredients = existing?.ingredients ?? []
        let ingredients = ingredientLines.enumerated().map { index, line in
            let existingIngredient = existingIngredients.indices.contains(index) ? existingIngredients[index] : nil
            let isUnchanged = existingIngredient?.ingredientText == line
            return RecipeIngredient(
                id: existingIngredient?.id ?? UUID(),
                sortIndex: index,
                ingredientText: line,
                ingredientPart: isUnchanged ? existingIngredient?.ingredientPart : nil,
                extraInformation: isUnchanged ? existingIngredient?.extraInformation : nil,
                quantity: isUnchanged ? existingIngredient?.quantity : nil,
                unit: isUnchanged ? existingIngredient?.unit : nil,
                emoji: isUnchanged ? existingIngredient?.emoji : nil,
                owned: isUnchanged ? existingIngredient?.owned ?? false : false
            )
        }

        return RecipeIngredientGroup(
            id: existing?.id ?? UUID(),
            title: existing?.title ?? "Ingredients",
            sortIndex: existing?.sortIndex ?? 0,
            ingredients: ingredients
        )
    }

    private func editedStepSection(existing: RecipeStepSection?) -> RecipeStepSection {
        let existingSteps = existing?.steps ?? []
        let steps = stepLines.enumerated().map { index, line in
            let existingStep = existingSteps.indices.contains(index) ? existingSteps[index] : nil
            let isUnchanged = existingStep?.instructionText == line
            return RecipeStep(
                id: existingStep?.id ?? UUID(),
                sortIndex: index,
                instructionText: line,
                timings: isUnchanged ? existingStep?.timings ?? [] : [],
                temperatures: isUnchanged ? existingStep?.temperatures ?? [] : [],
                linkedIngredients: isUnchanged ? existingStep?.linkedIngredients ?? [] : []
            )
        }

        return RecipeStepSection(
            id: existing?.id ?? UUID(),
            sortIndex: existing?.sortIndex ?? 0,
            title: existing?.title ?? "Method",
            steps: steps
        )
    }

    private func lines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
