//
//  MealplanEntry.swift
//  Models
//
//  Created by Tom Knighton on 17/11/2025.
//

import Foundation

public struct MealplanEntry: Sendable, Codable, Identifiable, Hashable {
    
    public let id: UUID
    public let date: Date
    public let index: Int
    public let note: String?
    public let recipe: Recipe?
    
    
    public init(id: UUID, date: Date, index: Int, note: String?, recipe: Recipe?) {
        self.id = id
        self.date = date
        self.index = index
        self.note = note
        self.recipe = recipe
    }
}
