//
//  MealplanToShoppingListFlowView.swift
//  Mealplans
//
//  Created by Tom Knighton on 22/03/2026.
//

import SwiftUI
import Dependencies
import Persistence
import Models
import Recipe
import Environment

struct MealplanToShoppingListFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.shoppingListMutations) private var shoppingMutations
    @Dependency(\.defaultDatabase) private var db

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var entryDrafts: [MealplanShoppingEntryDraft] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(initialStartDate: Date, initialEndDate: Date) {
        let normalizedStart = Calendar.current.startOfDay(for: initialStartDate)
        let normalizedEnd = Calendar.current.startOfDay(for: initialEndDate)
        _startDate = State(initialValue: normalizedStart)
        _endDate = State(initialValue: max(normalizedStart, normalizedEnd))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Timeframe") {
                    DatePicker("Start", selection: startDateBinding, displayedComponents: .date)
                    DatePicker("End", selection: endDateBinding, in: startDate..., displayedComponents: .date)

                    if isLoading {
                        ProgressView("Loading recipes...")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !isLoading && entryDrafts.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Recipe Ingredients",
                            systemImage: "fork.knife.circle",
                            description: Text("No recipe-based mealplan entries were found in this timeframe.")
                        )
                    }
                }

                ForEach($entryDrafts) { $entry in
                    Section {
                        ShoppingImportEntryEditor(
                            entry: $entry,
                            includeToggleTitle: "Include recipe"
                        )
                    } header: {
                        Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) · \(entry.recipeTitle)")
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
            .onAppear {
                Task { await refreshEntries() }
            }
            .onChange(of: startDate) { _, _ in
                Task { await refreshEntries() }
            }
            .onChange(of: endDate) { _, _ in
                Task { await refreshEntries() }
            }
        }
    }
}

private extension MealplanToShoppingListFlowView {
    var startDateBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newValue in
                let normalized = calendar.startOfDay(for: newValue)
                if endDate < normalized {
                    endDate = normalized
                }
                startDate = normalized
            }
        )
    }

    var endDateBinding: Binding<Date> {
        Binding(
            get: { endDate },
            set: { newValue in
                let normalized = calendar.startOfDay(for: newValue)
                endDate = max(normalized, startDate)
            }
        )
    }

    var selectedIngredientCount: Int {
        entryDrafts.reduce(0) { count, entry in
            guard entry.isSelected else { return count }
            return count + entry.ingredients.filter(\.isSelected).count
        }
    }

    func refreshEntries() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let queryStart = calendar.startOfDay(for: startDate)
        let queryEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate

        do {
            let drafts = try await db.read { db in
                let fullEntries = try DBMealplanEntry
                    .full(startDate: queryStart, endDate: queryEnd)
                    .fetchAll(db)
                    .sorted { lhs, rhs in
                        if lhs.mealplanEntry.date != rhs.mealplanEntry.date {
                            return lhs.mealplanEntry.date < rhs.mealplanEntry.date
                        }
                        return lhs.mealplanEntry.index < rhs.mealplanEntry.index
                    }

                var drafts: [MealplanShoppingEntryDraft] = []
                drafts.reserveCapacity(fullEntries.count)

                for fullEntry in fullEntries {
                    guard let recipeId = fullEntry.mealplanEntry.recipeId else { continue }
                    guard let fullRecipe = try DBRecipe.full.find(recipeId).fetchOne(db) else { continue }
                    let recipe = fullRecipe.toDomainModel()

                    let ingredients = recipe.ingredientSections
                        .sorted(by: { $0.sortIndex < $1.sortIndex })
                        .flatMap { section in
                            section.ingredients.sorted(by: { $0.sortIndex < $1.sortIndex })
                        }

                    guard !ingredients.isEmpty else { continue }

                    drafts.append(
                        MealplanShoppingEntryDraft(
                            mealplanEntryId: fullEntry.mealplanEntry.id,
                            date: fullEntry.mealplanEntry.date,
                            homeId: fullEntry.mealplanEntry.homeId,
                            recipeId: recipe.id,
                            recipeTitle: recipe.title,
                            isSelected: true,
                            scale: 1.0,
                            ingredients: ingredients.map {
                                MealplanShoppingIngredientDraft(
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

                return drafts
            }

            await MainActor.run {
                entryDrafts = drafts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load mealplan entries."
                isLoading = false
            }
            print("Failed to load mealplan shopping flow entries: \(error)")
        }
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
                            mealplanEntryId: $0.mealplanEntryId,
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
                print("Failed to persist mealplan shopping flow selections: \(error)")
            }
        }
    }

    func selectedShoppingPayloads() -> [SelectedShoppingPayload] {
        var payloads: [SelectedShoppingPayload] = []

        for entry in entryDrafts where entry.isSelected {
            for ingredient in entry.ingredients where ingredient.isSelected {
                payloads.append(
                    SelectedShoppingPayload(
                        mealplanEntryId: entry.mealplanEntryId,
                        ingredientId: ingredient.ingredientId,
                        homeId: entry.homeId,
                        scale: entry.scale,
                        title: ShoppingImportIngredientFormatter.scaledIngredientText(for: ingredient, scale: entry.scale)
                    )
                )
            }
        }

        return payloads
    }
}

private struct MealplanShoppingEntryDraft: Identifiable, Hashable {
    let mealplanEntryId: UUID
    let date: Date
    let homeId: UUID?
    let recipeId: UUID
    let recipeTitle: String
    var isSelected: Bool
    var scale: Double
    var ingredients: [MealplanShoppingIngredientDraft]

    var id: UUID { mealplanEntryId }
}

private struct MealplanShoppingIngredientDraft: Identifiable, Hashable {
    let id: UUID
    let ingredientId: UUID
    let ingredientText: String
    let ingredientPart: String?
    let quantity: Double?
    let quantityText: String?
    let unitText: String?
    var isSelected: Bool
}

private struct SelectedShoppingPayload: Hashable {
    let mealplanEntryId: UUID
    let ingredientId: UUID
    let homeId: UUID?
    let scale: Double
    let title: String
}

extension MealplanShoppingEntryDraft: ShoppingImportEntryRepresentable {}

extension MealplanShoppingIngredientDraft: ShoppingImportIngredientRepresentable {}
