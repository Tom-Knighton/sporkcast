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
        
        let shoppingList = ShoppingList(id: self.id, title: self.shoppingList.title, createdAt: self.shoppingList.createdAt, modifiedAt: self.shoppingList.modifiedAt, isArchived: self.shoppingList.isArchived, items: items)
        
        return shoppingList
    }
}
