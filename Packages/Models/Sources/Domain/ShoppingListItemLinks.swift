//
//  ShoppingListItemLinks.swift
//  Models
//
//  Created by Tom Knighton on 22/03/2026.
//

import Foundation
import Persistence

public struct ShoppingListItemIngredientLink: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public let shoppingListItemId: UUID
    public let ingredientId: UUID
    public let sourceScale: Double?
    public let addedAt: Date

    public init(
        id: UUID,
        shoppingListItemId: UUID,
        ingredientId: UUID,
        sourceScale: Double?,
        addedAt: Date
    ) {
        self.id = id
        self.shoppingListItemId = shoppingListItemId
        self.ingredientId = ingredientId
        self.sourceScale = sourceScale
        self.addedAt = addedAt
    }
}

public struct ShoppingListItemMealplanLink: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public let shoppingListItemId: UUID
    public let mealplanEntryId: UUID
    public let addedAt: Date

    public init(
        id: UUID,
        shoppingListItemId: UUID,
        mealplanEntryId: UUID,
        addedAt: Date
    ) {
        self.id = id
        self.shoppingListItemId = shoppingListItemId
        self.mealplanEntryId = mealplanEntryId
        self.addedAt = addedAt
    }
}

public extension DBShoppingListItemIngredientLink {
    func toDomainModel() -> ShoppingListItemIngredientLink {
        ShoppingListItemIngredientLink(
            id: id,
            shoppingListItemId: shoppingListItemId,
            ingredientId: ingredientId,
            sourceScale: sourceScale,
            addedAt: addedAt
        )
    }
}

public extension DBShoppingListItemMealplanLink {
    func toDomainModel() -> ShoppingListItemMealplanLink {
        ShoppingListItemMealplanLink(
            id: id,
            shoppingListItemId: shoppingListItemId,
            mealplanEntryId: mealplanEntryId,
            addedAt: addedAt
        )
    }
}
