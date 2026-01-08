//
//  RecipeRating.swift
//  Models
//
//  Created by Tom Knighton on 01/01/2026.
//

import Foundation

public struct RecipeRating: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let rating: Int?
    public let comment: String?
    
    public init(id: UUID, rating: Int?, comment: String?) {
        self.id = id
        self.rating = rating
        self.comment = comment
    }
}
