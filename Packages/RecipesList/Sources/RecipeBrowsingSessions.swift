import Observation
import SwiftUI

/// Keeps each folder's search and filters when switching navigation presentations.
@Observable
@MainActor
public final class RecipeBrowsingSessions {
    var snapshots: [String: RecipeBrowsingSnapshot] = [:]

    public init() {}

    public func clear() {
        snapshots.removeAll()
    }
}

extension EnvironmentValues {
    @Entry public var recipeBrowsingSessions: RecipeBrowsingSessions? = nil
}
