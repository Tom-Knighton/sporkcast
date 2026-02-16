//
//  ShoppingList.swift
//  Models
//
//  Created by Tom Knighton on 15/02/2026.
//

import Foundation

public struct ShoppingList {
    
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let isArchived: Bool
    
    public let items: [ShoppingListItem]
    
    public init(id: UUID, title: String, createdAt: Date, modifiedAt: Date, isArchived: Bool, items: [ShoppingListItem]) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isArchived = isArchived
        self.items = items
    }
}

public struct ShoppingListItem {
    
    public let id: UUID
    public var title: String
    public var isComplete: Bool
    
    public var categoryId: String
    public var categoryName: String
    public var categorySource: String?
}

extension ShoppingList: Sendable, Identifiable, Equatable, Hashable {
    
}

extension ShoppingListItem: Sendable, Identifiable, Equatable, Hashable {
    
}
