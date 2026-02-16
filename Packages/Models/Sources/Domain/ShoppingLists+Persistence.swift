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
        
        let shoppingList = ShoppingList(id: self.id, title: self.shoppingList.title, createdAt: self.shoppingList.createdAt, modifiedAt: self.shoppingList.modifiedAt, isArchived: self.shoppingList.isArchived)
        
        return shoppingList
    }
}
