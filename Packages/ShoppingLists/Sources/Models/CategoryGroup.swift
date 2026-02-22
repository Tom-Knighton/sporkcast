//
//  CategoryGroup.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 22/02/2026.
//

import Foundation
import Models

struct CategoryGroup: Identifiable {
    let id: String
    var names: [String]
    
    var items: [ShoppingListItem]
}
