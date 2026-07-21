//
//  RecipeSearchHandoff.swift
//  Environment
//
//  Created by Tom Knighton on 11/07/2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
public final class RecipeSearchHandoff {
    private static let appGroupSuiteName = "group.sporkcast"
    private static let pendingSearchKey = "intent.recipeSearch.query.v1"

    public struct Request: Equatable {
        public let id: UUID
        public let query: String
        public let shouldFocusSearch: Bool

        public init(id: UUID = UUID(), query: String, shouldFocusSearch: Bool) {
            self.id = id
            self.query = query
            self.shouldFocusSearch = shouldFocusSearch
        }
    }

    public static let shared = RecipeSearchHandoff()

    public private(set) var request: Request?

    private init() {}

    public func search(_ query: String, shouldFocusSearch: Bool = true) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        request = Request(query: trimmedQuery, shouldFocusSearch: shouldFocusSearch)
        UserDefaults(suiteName: Self.appGroupSuiteName)?.set(trimmedQuery, forKey: Self.pendingSearchKey)
    }

    public func consumePendingSearch() -> String? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupSuiteName),
              let query = defaults.string(forKey: Self.pendingSearchKey) else {
            return nil
        }

        defaults.removeObject(forKey: Self.pendingSearchKey)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        request = Request(query: trimmedQuery, shouldFocusSearch: true)
        return trimmedQuery
    }
}
