//
//  MealplanSpotlightEvents.swift
//  Environment
//
//  Created by Tom Knighton on 19/06/2026.
//

import Foundation
import Models

public enum MealplanSpotlightEvents {
    public static let indexRequested = Notification.Name("MealplanSpotlightEvents.indexRequested")
    public static let deleteRequested = Notification.Name("MealplanSpotlightEvents.deleteRequested")

    public static func requestIndex(ids: [MealplanEntry.ID]) {
        guard !ids.isEmpty else { return }
        NotificationCenter.default.post(name: indexRequested, object: ids)
    }

    public static func requestDelete(ids: [MealplanEntry.ID]) {
        guard !ids.isEmpty else { return }
        NotificationCenter.default.post(name: deleteRequested, object: ids)
    }
}
