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
    
    public var itemGroups: [ShoppingListItemGroup]
    
    public init(id: UUID, title: String, createdAt: Date, modifiedAt: Date, isArchived: Bool, itemGroups: [ShoppingListItemGroup]) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isArchived = isArchived
        self.itemGroups = itemGroups
    }
}

public struct ShoppingListItemGroup {
    public let id: String
    public var names: [String]
    
    public var items: [ShoppingListItem]
    
    public init(id: String, names: [String], items: [ShoppingListItem]) {
        self.id = id
        self.names = names
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
    
    public init(id: UUID, title: String, isComplete: Bool, categoryId: String, categoryName: String, categorySource: String? = nil) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categorySource = categorySource
    }
}

extension ShoppingList: Sendable, Identifiable, Equatable, Hashable {
    
}

extension ShoppingListItem: Sendable, Identifiable, Equatable, Hashable {
    
}

extension ShoppingListItemGroup: Sendable, Identifiable, Equatable, Hashable {}
