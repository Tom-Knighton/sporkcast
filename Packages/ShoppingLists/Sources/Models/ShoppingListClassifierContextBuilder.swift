//
//  ShoppingListClassifierContextBuilder.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import Models
import Persistence

enum ShoppingListClassifierContextBuilder {
    static func contextItems(
        dbItems: [DBShoppingListItem],
        fallbackList: ShoppingList?
    ) -> [ShoppingListItem] {
        guard !dbItems.isEmpty else {
            return fallbackList?.itemGroups.flatMap(\.items) ?? []
        }

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

    private static func sourcePriority(_ source: String) -> Int {
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
