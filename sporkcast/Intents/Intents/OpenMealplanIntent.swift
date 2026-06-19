//
//  OpenMealplanIntent.swift
//  Sporkast
//
//  Created by Tom Knighton on 15/06/2026.
//

import Foundation
import AppIntents
import Environment

public struct OpenMealplanIntent: AppIntent {
    
    public static let title: LocalizedStringResource = "Open Weekly Mealplan"
    public static let supportedModes: IntentModes = .foreground(.immediate)
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        AppRouter.shared.selectTab(.mealplan)
        return .result()
    }
}
