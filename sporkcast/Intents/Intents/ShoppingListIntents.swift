//
//  ShoppingListIntents.swift
//  sporkcast
//

import AppIntents
internal import AppRouter
import Environment
import Foundation
import Models
import SwiftUI

@available(anyAppleOS 27.0, *)
public struct OpenGroceriesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Groceries"
    public static let description = IntentDescription("Opens groceries in Sporkcast.")
    public static let supportedModes: IntentModes = .foreground(.immediate)

    public static var parameterSummary: some ParameterSummary {
        Summary("Open groceries")
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        AppRouter.shared.selectedTab = .shoppingLists
        return .result(dialog: "Opening groceries.")
    }
}

@available(anyAppleOS 27.0, *)
public struct GetGroceriesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Groceries"
    public static let description = IntentDescription("Shows open grocery items in Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @MainActor private var repository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Show groceries")
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[ShoppingItemEntity]> & ProvidesDialog {
        let groceries = try await repository
            .shoppingListItems(homeId: HouseholdService.shared.home?.id)
            .filter { !$0.isComplete }
            .map(ShoppingItemEntity.init(item:))

        let dialog: IntentDialog = groceries.isEmpty
            ? "There are no open grocery items."
            : "You have \(groceries.count) grocery item\(groceries.count == 1 ? "" : "s")."

        return .result(value: groceries, dialog: dialog)
    }
}

@available(anyAppleOS 27.0, *)
public struct CreateShoppingListIntent: AppIntent {
    public static let title: LocalizedStringResource = "Create Shopping List"
    public static let description = IntentDescription("Creates a new Sporkcast shopping list.")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Title")
    public var title: String

    @MainActor private var repository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Create shopping list named \(\.$title)")
    }

    public init() {
        self.title = "Shopping List"
    }

    public init(title: String = "Shopping List") {
        self.title = title
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let listTitle = trimmedTitle.isEmpty ? "Shopping List" : trimmedTitle
        _ = try await repository.createShoppingList(homeId: HouseholdService.shared.home?.id, title: listTitle)
        return .result(dialog: "Created \(listTitle).")
    }
}

@available(anyAppleOS 27.0, *)
public struct AddGroceryItemIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Grocery Item"
    public static let description = IntentDescription("Adds an item to groceries in Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Item", requestValueDialog: "What should I add?")
    public var title: String

    @MainActor private var repository = ShoppingListMutationRepository()
    private let classifier = ShoppingCategoryClassifier()

    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) to groceries")
    }

    public init() {
        self.title = ""
    }

    public init(title: String) {
        self.title = title
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let itemTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemTitle.isEmpty else {
            return .result(dialog: "I couldn't tell what grocery item to add.")
        }

        let homeId = HouseholdService.shared.home?.id
        let listId = try await repository.ensureActiveShoppingList(homeId: homeId)
        let knownItems = try await repository.shoppingListItems(homeId: homeId)
        let category = classifier.classify(itemTitle, fallback: .unknown, knownItems: knownItems)
        let categorySource = category == .unknown ? "manual" : "classifier"

        _ = try await repository.addItem(
            listId: listId,
            title: itemTitle,
            isComplete: false,
            category: category,
            categorySource: categorySource
        )

        return .result(dialog: "Added \(itemTitle) to groceries.")
    }
}

@available(anyAppleOS 27.0, *)
public struct AddRecipeIngredientsToGroceriesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Recipe Ingredients to Groceries"
    public static let description = IntentDescription("Adds all ingredients from a Sporkcast recipe to groceries.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Recipe",
        requestValueDialog: "Which recipe should I add ingredients from?",
        requestDisambiguationDialog: "Which recipe did you mean?",
        query: RecipeEntryEntityQuery()
    )
    public var recipe: RecipeEntity

    @MainActor private var recipeRepository = RecipesRepository(observesChanges: false)
    @MainActor private var shoppingRepository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Add ingredients for \(\.$recipe) to groceries")
    }

    public init() {}

    public init(recipe: RecipeEntity) {
        self.recipe = recipe
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let fullRecipe = try await recipeRepository.getById([recipe.id]).first else {
            return .result(dialog: "I couldn't find that recipe.")
        }

        let payloads = fullRecipe.ingredientSections
            .sorted { $0.sortIndex < $1.sortIndex }
            .flatMap { section in
                section.ingredients
                    .sorted { $0.sortIndex < $1.sortIndex }
                    .map { ingredient in
                        ShoppingListImportPayload(
                            ingredientId: ingredient.id,
                            homeId: fullRecipe.homeId ?? HouseholdService.shared.home?.id,
                            scale: fullRecipe.ingredientScale,
                            title: ingredient.ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
            }
            .filter { !$0.title.isEmpty }

        guard !payloads.isEmpty else {
            return .result(dialog: "\(fullRecipe.title) doesn't have ingredients to add.")
        }

        try await shoppingRepository.addImportedItems(payloads)
        return .result(dialog: "Added \(payloads.count) ingredient\(payloads.count == 1 ? "" : "s") from \(fullRecipe.title) to groceries.")
    }
}

@available(anyAppleOS 27.0, *)
public struct RenameGroceryItemIntent: AppIntent {
    public static let title: LocalizedStringResource = "Rename Grocery Item"
    public static let description = IntentDescription("Renames a grocery item in Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Item",
        requestValueDialog: "Which grocery item should I rename?",
        requestDisambiguationDialog: "Which grocery item did you mean?",
        query: ShoppingItemEntityQuery()
    )
    public var item: ShoppingItemEntity

    @Parameter(title: "New Name", requestValueDialog: "What should it be called?")
    public var title: String

    @MainActor private var repository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Rename \(\.$item) to \(\.$title)")
    }

    public init() {
        self.title = ""
    }

    public init(item: ShoppingItemEntity, title: String) {
        self.item = item
        self.title = title
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else {
            return .result(dialog: "I couldn't tell what to rename it to.")
        }

        let listId = try await repository.listIdForItem(item.id)
        try await repository.updateItemTitle(itemId: item.id, listId: listId, title: newTitle)
        return .result(dialog: "Renamed \(item.title) to \(newTitle).")
    }
}

@available(anyAppleOS 27.0, *)
public struct CompleteGroceryItemIntent: AppIntent {
    public static let title: LocalizedStringResource = "Complete Grocery Item"
    public static let description = IntentDescription("Marks a grocery item complete in Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Item",
        requestValueDialog: "Which grocery item is complete?",
        requestDisambiguationDialog: "Which grocery item did you mean?",
        query: ShoppingItemEntityQuery()
    )
    public var item: ShoppingItemEntity

    @MainActor private var repository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$item)")
    }

    public init() {}

    public init(item: ShoppingItemEntity) {
        self.item = item
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let listId = try await repository.listIdForItem(item.id)
        try await repository.setItemCompletion(itemId: item.id, listId: listId, isComplete: true)
        return .result(dialog: "Marked \(item.title) complete.")
    }
}

@available(anyAppleOS 27.0, *)
public struct DeleteGroceryItemIntent: AppIntent {
    public static let title: LocalizedStringResource = "Delete Grocery Item"
    public static let description = IntentDescription("Deletes a grocery item from Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Item",
        requestValueDialog: "Which grocery item should I delete?",
        requestDisambiguationDialog: "Which grocery item did you mean?",
        query: ShoppingItemEntityQuery()
    )
    public var item: ShoppingItemEntity

    @MainActor private var repository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$item)")
    }

    public init() {}

    public init(item: ShoppingItemEntity) {
        self.item = item
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let listId = try await repository.listIdForItem(item.id)
        try await repository.deleteItem(itemId: item.id, listId: listId)
        return .result(dialog: "Deleted \(item.title) from groceries.")
    }
}

@available(anyAppleOS 27.0, *)
public struct ClearGroceriesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Clear Groceries"
    public static let description = IntentDescription("Clears a Sporkcast shopping list.")
    public static let supportedModes: IntentModes = .background
    public static let openAppWhenRun = true

    @Parameter(
        title: "Shopping List",
        requestValueDialog: "Which shopping list should I clear?",
        requestDisambiguationDialog: "Which shopping list did you mean?",
        query: ShoppingListEntityQuery()
    )
    public var list: ShoppingListEntity

    @MainActor private var repository = ShoppingListMutationRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Clear \(\.$list)")
    }

    public init() {}

    public init(list: ShoppingListEntity) {
        self.list = list
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await repository.clearList(listId: list.id)
        return .result(dialog: "Cleared \(list.title).")
    }
}
