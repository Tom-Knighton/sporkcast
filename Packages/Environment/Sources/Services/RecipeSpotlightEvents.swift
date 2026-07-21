//
//  RecipeSpotlightEvents.swift
//  Environment
//
//  Created by Tom Knighton on 29/06/2026.
//

import Foundation
import Models

public enum RecipeSpotlightEvents {
    public static let indexRequested = Notification.Name("RecipeSpotlightEvents.indexRequested")
    public static let deleteRequested = Notification.Name("RecipeSpotlightEvents.deleteRequested")
    public static let deleteAllRequested = Notification.Name("RecipeSpotlightEvents.deleteAllRequested")

    public static func requestIndex(ids: [Recipe.ID]) {
        guard !ids.isEmpty else { return }
        NotificationCenter.default.post(name: indexRequested, object: ids)
    }

    public static func requestDelete(ids: [Recipe.ID]) {
        guard !ids.isEmpty else { return }
        NotificationCenter.default.post(name: deleteRequested, object: ids)
    }

    public static func requestDeleteAll() {
        NotificationCenter.default.post(name: deleteAllRequested, object: nil)
    }
}
