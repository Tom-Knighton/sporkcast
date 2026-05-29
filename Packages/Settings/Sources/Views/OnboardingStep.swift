//
//  OnboardingStep.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import SwiftUI

struct OnboardingStep: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    let features: [String]
    let showsProCTA: Bool

    static let all: [OnboardingStep] = [
        OnboardingStep(
            id: "capture",
            title: "Bring every recipe into one kitchen",
            subtitle: "Save the dishes you already love, import new finds, and keep everything ready when dinner starts moving.",
            symbolName: "book.closed.fill",
            tint: .orange,
            features: ["Import from links", "Edit ingredients fast", "Cook from a clean recipe view"],
            showsProCTA: false
        ),
        OnboardingStep(
            id: "plan",
            title: "Turn good intentions into a mealplan",
            subtitle: "Drop recipes onto the week, keep plans visible, and let Sporkast help you answer what is for dinner before everyone asks.",
            symbolName: "calendar",
            tint: .green,
            features: ["Weekly mealplans", "Weather-aware planning", "Calendar sync with Pro"],
            showsProCTA: false
        ),
        OnboardingStep(
            id: "shop",
            title: "Build the shopping list without retyping",
            subtitle: "Send recipe ingredients into groceries, tidy them by category, and keep the list practical at the store.",
            symbolName: "cart.fill",
            tint: .blue,
            features: ["Recipe-to-list flow", "Organized groceries", "Reminder list sync"],
            showsProCTA: false
        ),
        OnboardingStep(
            id: "pro",
            title: "Make Sporkast your cooking system",
            subtitle: "Sporkast Pro unlocks deeper organization, social imports, discovery, widgets, weather, and Calendar sync when you are ready to go all in.",
            symbolName: "sparkles",
            tint: .purple,
            features: ["Folders and tags", "Social recipe imports", "Widgets and Calendar sync"],
            showsProCTA: true
        )
    ]
}
