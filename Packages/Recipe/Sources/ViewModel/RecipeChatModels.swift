//
//  RecipeChatModels.swift
//  Recipe
//
//  Created by Tom Knighton on 12/04/2026.
//

import Foundation
import FoundationModels

enum RecipeChatRole: String, Codable, Sendable {
    case user
    case assistant
}

struct RecipeChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let role: RecipeChatRole
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: RecipeChatRole,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

@Generable
struct RecipeChatTurnResponse: Sendable {
    let isRecipeRelated: Bool
    let reply: String
}
