//
//  ShoppingEntities.swift
//  sporkcast
//

import AppIntents
import Environment
import Foundation
import Models

@available(anyAppleOS 27.0, *)
public struct ShoppingListEntity: AppEntity, Identifiable, Sendable {
    public static let defaultQuery = ShoppingListEntityQuery()
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shopping List")

    public let id: UUID

    @Property(title: "Title")
    public var title: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: "cart"))
    }

    public init(list: ShoppingList) {
        self.id = list.id
        self.title = list.title
    }
}

@available(anyAppleOS 27.0, *)
public struct ShoppingListEntityQuery: EntityStringQuery {
    @MainActor private var repository = ShoppingListMutationRepository()

    public init() {}

    public func entities(for identifiers: [ShoppingListEntity.ID]) async throws -> [ShoppingListEntity] {
        let lists = try await repository.activeShoppingLists(homeId: HouseholdService.shared.home?.id)
        return lists
            .filter { identifiers.contains($0.id) }
            .map(ShoppingListEntity.init(list:))
    }

    public func suggestedEntities() async throws -> [ShoppingListEntity] {
        try await repository
            .activeShoppingLists(homeId: HouseholdService.shared.home?.id)
            .map(ShoppingListEntity.init(list:))
    }

    public func entities(matching string: String) async throws -> [ShoppingListEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let lists = try await repository.activeShoppingLists(homeId: HouseholdService.shared.home?.id)

        guard !query.isEmpty else {
            return lists.map(ShoppingListEntity.init(list:))
        }

        return lists
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .map(ShoppingListEntity.init(list:))
    }
}

@available(anyAppleOS 27.0, *)
public struct ShoppingItemEntity: AppEntity, Identifiable, Sendable {
    public static let defaultQuery = ShoppingItemEntityQuery()
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Grocery Item")

    public let id: UUID

    @Property(title: "Title")
    public var title: String

    @Property(title: "Complete")
    public var isComplete: Bool

    @Property(title: "Category")
    public var categoryName: String

    public var displayRepresentation: DisplayRepresentation {
        let imageName = isComplete ? "checkmark.circle" : "circle"
        return DisplayRepresentation(title: "\(title)", subtitle: "\(categoryName)", image: .init(systemName: imageName))
    }

    public init(item: ShoppingListItem) {
        self.id = item.id
        self.title = item.title
        self.isComplete = item.isComplete
        self.categoryName = item.categoryName
    }
}

@available(anyAppleOS 27.0, *)
public struct ShoppingItemEntityQuery: EntityStringQuery {
    @MainActor private var repository = ShoppingListMutationRepository()

    public init() {}

    public func entities(for identifiers: [ShoppingItemEntity.ID]) async throws -> [ShoppingItemEntity] {
        try await repository.shoppingListItems(ids: identifiers).map(ShoppingItemEntity.init(item:))
    }

    public func suggestedEntities() async throws -> [ShoppingItemEntity] {
        try await repository
            .shoppingListItems(homeId: HouseholdService.shared.home?.id)
            .filter { !$0.isComplete }
            .map(ShoppingItemEntity.init(item:))
    }

    public func entities(matching string: String) async throws -> [ShoppingItemEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = try await repository.shoppingListItems(homeId: HouseholdService.shared.home?.id)

        guard !query.isEmpty else {
            return items.map(ShoppingItemEntity.init(item:))
        }

        return items
            .filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                    || item.categoryName.localizedCaseInsensitiveContains(query)
            }
            .map(ShoppingItemEntity.init(item:))
    }
}
