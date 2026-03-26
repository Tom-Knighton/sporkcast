import Dependencies
import Foundation
import Models
import Persistence
import SQLiteData

public struct ShoppingListImportPayload: Sendable, Hashable {
    public let ingredientId: UUID
    public let mealplanEntryId: UUID?
    public let homeId: UUID?
    public let scale: Double?
    public let title: String

    public init(
        ingredientId: UUID,
        mealplanEntryId: UUID? = nil,
        homeId: UUID?,
        scale: Double?,
        title: String
    ) {
        self.ingredientId = ingredientId
        self.mealplanEntryId = mealplanEntryId
        self.homeId = homeId
        self.scale = scale
        self.title = title
    }
}

public final class ShoppingListMutationRepository {

    @Dependency(\.defaultDatabase) private var database

    private let classifier = ShoppingCategoryClassifier()

    public init() {}

    @MainActor
    public func createShoppingList(homeId: UUID?, title: String = "Shopping List") async throws -> UUID {
        let listId = UUID()
        let now = Date()

        try await database.write { db in
            try DBShoppingList.insert {
                DBShoppingList(
                    id: listId,
                    homeId: homeId,
                    title: title,
                    createdAt: now,
                    modifiedAt: now,
                    isArchived: false
                )
            }
            .execute(db)
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
        return listId
    }

    @MainActor
    public func ensureActiveShoppingList(homeId: UUID?) async throws -> UUID {
        try await database.write { db in
            let existing = try DBShoppingList
                .where(\.isArchived)
                .not()
                .order(by: \.createdAt)
                .select(\.id)
                .fetchAll(db)

            if let id = existing.first {
                return id
            }

            let now = Date()
            let listId = UUID()
            try DBShoppingList.insert {
                DBShoppingList(
                    id: listId,
                    homeId: homeId,
                    title: "Shopping List",
                    createdAt: now,
                    modifiedAt: now,
                    isArchived: false
                )
            }
            .execute(db)

            return listId
        }
    }

    @MainActor
    public func addItem(
        listId: UUID,
        title: String,
        isComplete: Bool,
        category: ShoppingCategory,
        categorySource: String,
        modifiedAt: Date = Date()
    ) async throws -> UUID {
        let itemId = UUID()

        try await database.write { db in
            try DBShoppingListItem.insert {
                DBShoppingListItem(
                    id: itemId,
                    title: title,
                    listId: listId,
                    isComplete: isComplete,
                    modifiedAt: modifiedAt,
                    categoryIdentifier: category.rawValue,
                    categoryDisplayName: category.displayName,
                    categorySource: categorySource
                )
            }
            .execute(db)

            try DBShoppingList.find(listId).update {
                $0.modifiedAt = modifiedAt
            }
            .execute(db)
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
        return itemId
    }

    @MainActor
    public func updateItemTitle(itemId: UUID, listId: UUID?, title: String, modifiedAt: Date = Date()) async throws {
        try await database.write { db in
            try DBShoppingListItem.find(itemId).update {
                $0.title = title
                $0.modifiedAt = modifiedAt
            }
            .execute(db)

            if let listId {
                try DBShoppingList.find(listId).update {
                    $0.modifiedAt = modifiedAt
                }
                .execute(db)
            }
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
    }

    @MainActor
    public func setItemCompletion(itemId: UUID, listId: UUID?, isComplete: Bool, modifiedAt: Date = Date()) async throws {
        try await database.write { db in
            try DBShoppingListItem.find(itemId).update {
                $0.isComplete = isComplete
                $0.modifiedAt = modifiedAt
            }
            .execute(db)

            if let listId {
                try DBShoppingList.find(listId).update {
                    $0.modifiedAt = modifiedAt
                }
                .execute(db)
            }
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
    }

    @MainActor
    public func updateItemCategory(
        itemId: UUID,
        listId: UUID?,
        category: ShoppingCategory,
        source: String,
        modifiedAt: Date = Date()
    ) async throws {
        try await database.write { db in
            try DBShoppingListItem.find(itemId).update {
                $0.categoryIdentifier = category.rawValue
                $0.categoryDisplayName = category.displayName
                $0.categorySource = source
                $0.modifiedAt = modifiedAt
            }
            .execute(db)

            if let listId {
                try DBShoppingList.find(listId).update {
                    $0.modifiedAt = modifiedAt
                }
                .execute(db)
            }
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
    }

    @MainActor
    public func clearList(listId: UUID) async throws {
        let itemIDs = try await database.read { db in
            try DBShoppingListItem
                .where { $0.listId == listId }
                .select(\.id)
                .fetchAll(db)
        }

        try await ShoppingListRemindersSyncService.shared.prepareForLocalItemDeletion(itemIDs: itemIDs)

        try await database.write { db in
            try DBShoppingListItem
                .where { $0.listId == listId }
                .delete()
                .execute(db)

            try DBShoppingList.find(listId).update {
                $0.modifiedAt = Date()
            }
            .execute(db)
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
    }

    @MainActor
    public func addImportedItems(_ payloads: [ShoppingListImportPayload]) async throws {
        guard !payloads.isEmpty else { return }
        let classifier = self.classifier

        try await database.write { db in
            let now = Date()
            let existingListIDs = try DBShoppingList
                .where(\.isArchived)
                .not()
                .order(by: \.createdAt)
                .select(\.id)
                .fetchAll(db)

            let listId: UUID
            if let existingID = existingListIDs.first {
                listId = existingID
            } else {
                let newListID = UUID()
                try DBShoppingList.insert {
                    DBShoppingList(
                        id: newListID,
                        homeId: payloads.first?.homeId,
                        title: "Shopping List",
                        createdAt: now,
                        modifiedAt: now,
                        isArchived: false
                    )
                }
                .execute(db)
                listId = newListID
            }

            let dbClassifierItems = try DBShoppingListItem.all.fetchAll(db)
            var classifierKnownItems = Self.classifierContextItems(from: dbClassifierItems)

            for payload in payloads {
                let itemId = UUID()
                let inferredCategory = classifier.classify(
                    payload.title,
                    fallback: .unknown,
                    knownItems: classifierKnownItems
                )
                let categorySource = inferredCategory == .unknown ? "manual" : "classifier"

                try DBShoppingListItem.insert {
                    DBShoppingListItem(
                        id: itemId,
                        title: payload.title,
                        listId: listId,
                        isComplete: false,
                        modifiedAt: now,
                        categoryIdentifier: inferredCategory.rawValue,
                        categoryDisplayName: inferredCategory.displayName,
                        categorySource: categorySource
                    )
                }
                .execute(db)

                classifierKnownItems.append(
                    ShoppingListItem(
                        id: itemId,
                        title: payload.title,
                        isComplete: false,
                        categoryId: inferredCategory.rawValue,
                        categoryName: inferredCategory.displayName,
                        categorySource: categorySource
                    )
                )

                try DBShoppingListItemIngredientLink.insert {
                    DBShoppingListItemIngredientLink(
                        id: UUID(),
                        shoppingListItemId: itemId,
                        ingredientId: payload.ingredientId,
                        sourceScale: payload.scale,
                        addedAt: now
                    )
                }
                .execute(db)

                if let mealplanEntryId = payload.mealplanEntryId {
                    try DBShoppingListItemMealplanLink.insert {
                        DBShoppingListItemMealplanLink(
                            id: UUID(),
                            shoppingListItemId: itemId,
                            mealplanEntryId: mealplanEntryId,
                            addedAt: now
                        )
                    }
                    .execute(db)
                }
            }

            try DBShoppingList.find(listId).update {
                $0.modifiedAt = now
            }
            .execute(db)
        }

        await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .localMutation)
    }
}

private extension ShoppingListMutationRepository {
    static func classifierContextItems(from dbItems: [DBShoppingListItem]) -> [ShoppingListItem] {
        guard !dbItems.isEmpty else { return [] }

        var bestItemsByKey: [String: DBShoppingListItem] = [:]
        bestItemsByKey.reserveCapacity(dbItems.count)

        for item in dbItems {
            let normalizedTitle = item.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalizedTitle.isEmpty else { continue }

            let categoryIdentifier = item.categoryIdentifier ?? ShoppingCategory.unknown.rawValue
            let key = "\(categoryIdentifier)|\(normalizedTitle)"

            if let existing = bestItemsByKey[key],
               sourcePriority(item.categorySource) <= sourcePriority(existing.categorySource) {
                continue
            }

            bestItemsByKey[key] = item
        }

        return bestItemsByKey.values.map { dbItem in
            ShoppingListItem(
                id: dbItem.id,
                title: dbItem.title,
                isComplete: dbItem.isComplete,
                categoryId: dbItem.categoryIdentifier ?? ShoppingCategory.unknown.rawValue,
                categoryName: dbItem.categoryDisplayName,
                categorySource: dbItem.categorySource
            )
        }
    }

    static func sourcePriority(_ source: String) -> Int {
        switch source.lowercased() {
        case "manual", "suggestion":
            return 3
        case "classifier":
            return 1
        default:
            return 2
        }
    }
}
