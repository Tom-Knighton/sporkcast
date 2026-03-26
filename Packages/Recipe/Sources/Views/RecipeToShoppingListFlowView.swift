//
//  RecipeToShoppingListFlowView.swift
//  Recipe
//
//  Created by Tom Knighton on 23/03/2026.
//

import SwiftUI
import Models
import Environment

struct RecipeToShoppingListFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.shoppingListMutations) private var shoppingMutations

    private let recipe: Recipe

    @State private var entryDraft: RecipeShoppingEntryDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(recipe: Recipe) {
        self.recipe = recipe

        let ingredients = recipe.ingredientSections
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .flatMap { section in
                section.ingredients.sorted(by: { $0.sortIndex < $1.sortIndex })
            }

        _entryDraft = State(
            initialValue: RecipeShoppingEntryDraft(
                recipeId: recipe.id,
                homeId: recipe.homeId,
                recipeTitle: recipe.title,
                isSelected: true,
                scale: 1.0,
                ingredients: ingredients.map {
                    RecipeShoppingIngredientDraft(
                        id: $0.id,
                        ingredientId: $0.id,
                        ingredientText: $0.ingredientText,
                        ingredientPart: $0.ingredientPart,
                        quantity: $0.quantity?.quantity,
                        quantityText: $0.quantity?.quantityText,
                        unitText: $0.unit?.unitText,
                        isSelected: true
                    )
                }
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if entryDraft.ingredients.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Ingredients",
                            systemImage: "cart.badge.minus",
                            description: Text("This recipe has no ingredients to add right now.")
                        )
                    }
                } else {
                    Section {
                        ShoppingImportEntryEditor(
                            entry: $entryDraft,
                            includeToggleTitle: "Include recipe"
                        )
                    } header: {
                        Text(entryDraft.recipeTitle)
                    }
                }
            }
            .navigationTitle("Add To Shopping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedIngredientCount)") {
                        addSelectedIngredientsToShoppingList()
                    }
                    .disabled(isSaving || selectedIngredientCount == 0)
                }
            }
        }
    }
}

private extension RecipeToShoppingListFlowView {
    var selectedIngredientCount: Int {
        guard entryDraft.isSelected else { return 0 }
        return entryDraft.ingredients.filter(\.isSelected).count
    }

    func addSelectedIngredientsToShoppingList() {
        guard !isSaving else { return }

        let selectedPayloads = selectedShoppingPayloads()
        guard !selectedPayloads.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await shoppingMutations.addImportedItems(
                    selectedPayloads.map {
                        ShoppingListImportPayload(
                            ingredientId: $0.ingredientId,
                            mealplanEntryId: nil,
                            homeId: $0.homeId,
                            scale: $0.scale,
                            title: $0.title
                        )
                    }
                )

                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to add selected ingredients to shopping list."
                }
                print("Failed to persist recipe shopping flow selections: \(error)")
            }
        }
    }

    func selectedShoppingPayloads() -> [RecipeSelectedShoppingPayload] {
        guard entryDraft.isSelected else { return [] }

        return entryDraft.ingredients
            .filter(\.isSelected)
            .map {
                RecipeSelectedShoppingPayload(
                    ingredientId: $0.ingredientId,
                    homeId: entryDraft.homeId,
                    scale: entryDraft.scale,
                    title: ShoppingImportIngredientFormatter.scaledIngredientText(for: $0, scale: entryDraft.scale)
                )
            }
    }
}

private struct RecipeShoppingEntryDraft: Identifiable, Hashable {
    let recipeId: UUID
    let homeId: UUID?
    let recipeTitle: String
    var isSelected: Bool
    var scale: Double
    var ingredients: [RecipeShoppingIngredientDraft]

    var id: UUID { recipeId }
}

private struct RecipeShoppingIngredientDraft: Identifiable, Hashable {
    let id: UUID
    let ingredientId: UUID
    let ingredientText: String
    let ingredientPart: String?
    let quantity: Double?
    let quantityText: String?
    let unitText: String?
    var isSelected: Bool
}

private struct RecipeSelectedShoppingPayload: Hashable {
    let ingredientId: UUID
    let homeId: UUID?
    let scale: Double
    let title: String
}

extension RecipeShoppingEntryDraft: ShoppingImportEntryRepresentable {}

extension RecipeShoppingIngredientDraft: ShoppingImportIngredientRepresentable {}
