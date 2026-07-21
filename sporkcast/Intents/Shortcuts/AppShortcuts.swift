//
//  OpenMealplanShortcut.swift
//  sporkcast
//
//  Created by Tom Knighton on 15/06/2026.
//

import AppIntents

struct OpenMealplanShortcut: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMealplanIntent(),
            phrases: [
                "Open my weekly mealplan in \(.applicationName)",
                "Open my mealplan in \(.applicationName)",
            ],
            shortTitle: "Mealplan",
            systemImageName: "calendar"
        )
        
        if #available(iOS 27.0, *) {
            AppShortcut(
                intent: OpenRecipeIntent(),
                phrases: [
                    "Open \(\.$target) in \(.applicationName)",
                    "Show \(\.$target) in \(.applicationName)",
                    "Cook \(\.$target) in \(.applicationName)"
                ],
                shortTitle: "Open Recipe",
                systemImageName: "fork.knife"
            )

            AppShortcut(
                intent: FindRecipesShortcutIntent(),
                phrases: [
                    "Open recipe search in \(.applicationName)",
                    "Open my cookbook in \(.applicationName)",
                    "Browse recipes in \(.applicationName)"
                ],
                shortTitle: "Recipe Search",
                systemImageName: "magnifyingglass"
            )

            AppShortcut(
                intent: GetRecipeDetailsIntent(),
                phrases: [
                    "What ingredients do I need for \(\.$recipe) in \(.applicationName)",
                    "Show ingredients for \(\.$recipe) in \(.applicationName)",
                    "Tell me about \(\.$recipe) in \(.applicationName)"
                ],
                shortTitle: "Recipe Details",
                systemImageName: "list.bullet.clipboard"
            )

            AppShortcut(
                intent: GetPlannedMealIntent(),
                phrases: [
                    "What is on my mealplan in \(.applicationName)",
                    "What is on my mealplan \(\.$period) in \(.applicationName)",
                    "What's on my mealplan \(\.$period) in \(.applicationName)",
                    "What am I eating \(\.$period) in \(.applicationName)",
                    "Show my mealplan in \(.applicationName)",
                    "Show my mealplan \(\.$period) in \(.applicationName)",
                    "What do I have for dinner \(\.$period) in \(.applicationName)",
                    "What's on the mealplan \(\.$period) in \(.applicationName)",
                    "What meals are planned \(\.$period) in \(.applicationName)"
                ],
                shortTitle: "Mealplan",
                systemImageName: "fork.knife"
            )
        }
    }
}
