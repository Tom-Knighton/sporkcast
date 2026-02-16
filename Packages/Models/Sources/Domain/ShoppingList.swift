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
    
    public init(id: UUID, title: String, createdAt: Date, modifiedAt: Date, isArchived: Bool) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isArchived = isArchived
    }
}

extension ShoppingList: Sendable, Identifiable, Equatable, Hashable {
    
}
