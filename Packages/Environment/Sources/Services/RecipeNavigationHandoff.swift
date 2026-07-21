//
//  RecipeNavigationHandoff.swift
//  Environment
//
//  Created by Tom Knighton on 12/07/2026.
//

import Foundation

@MainActor
@Observable
public final class RecipeNavigationHandoff {
    private static let appGroupSuiteName = "group.sporkcast"
    private static let pendingRecipeIDKey = "intent.openRecipe.id.v1"

    public struct Request: Equatable {
        public let id: UUID
        public let recipeId: UUID

        public init(id: UUID = UUID(), recipeId: UUID) {
            self.id = id
            self.recipeId = recipeId
        }
    }

    public static let shared = RecipeNavigationHandoff()

    public private(set) var request: Request?

    private init() {}

    public func open(recipeId: UUID) {
        request = Request(recipeId: recipeId)
        UserDefaults(suiteName: Self.appGroupSuiteName)?.set(recipeId.uuidString, forKey: Self.pendingRecipeIDKey)
    }

    public func consumePendingRecipeId() -> UUID? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupSuiteName),
              let idString = defaults.string(forKey: Self.pendingRecipeIDKey) else {
            return nil
        }

        defaults.removeObject(forKey: Self.pendingRecipeIDKey)
        return UUID(uuidString: idString)
    }
}
