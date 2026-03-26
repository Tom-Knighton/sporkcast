//
//  ShoppingListDisplaySection.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import Models

struct ShoppingListDisplaySection: Identifiable {
    let section: ShoppingListItemGroup
    let visibleItems: [ShoppingListItem]

    var id: String { section.id }
}
