//
//  ShoppingLists+Persistence.swift
//  Models
//
//  Created by Tom Knighton on 15/02/2026.
//

import Foundation
import Persistence

public extension FullDBShoppingList {
    
    func toDomain() -> ShoppingList {
        
        let items = self.items.compactMap {
            ShoppingListItem(id: $0.id, title: $0.title, isComplete: $0.isComplete, categoryId: $0.categoryIdentifier ?? "unknown", categoryName: $0.categoryDisplayName, categorySource: $0.categorySource)
        }
        
        var groups: [ShoppingListItemGroup] = []
        items.forEach { item in
            if let index = groups.firstIndex(where: { $0.id == item.categoryId }) {
                if !groups[index].names.contains(item.categoryName) {
                    groups[index].names.append(item.categoryName)
                }
                groups[index].items.append(item)
            } else {
                groups.append(.init(id: item.categoryId, names: [item.categoryName], items: [item]))
            }
        }
        
        if !groups.contains(where: { $0.id == "unknown" }) {
            groups.append(.init(id: "unknown", names: ["Other"], items: []))
        }
        
        let shoppingList = ShoppingList(id: self.id, title: self.shoppingList.title, createdAt: self.shoppingList.createdAt, modifiedAt: self.shoppingList.modifiedAt, isArchived: self.shoppingList.isArchived, itemGroups: groups)
        
        return shoppingList
    }
}
