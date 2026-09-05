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

            AppShortcut(
                intent: ImportRecipeFromWebsiteAndAddToMealplanIntent(),
                phrases: [
                    "Import this website into \(.applicationName) and add it to mealplan",
                    "Import this recipe into \(.applicationName) and add it to mealplan",
                    "Save this recipe to \(.applicationName) and plan it"
                ],
                shortTitle: "Import and Plan",
                systemImageName: "calendar.badge.plus"
            )

            AppShortcut(
                intent: AddRecipeToMealplanIntent(),
                phrases: [
                    "Add \(\.$recipe) to my mealplan in \(.applicationName)",
                    "Plan \(\.$recipe) in \(.applicationName)"
                ],
                shortTitle: "Plan Recipe",
                systemImageName: "calendar.badge.plus"
            )

            AppShortcut(
                intent: AddRandomMealToMealplanIntent(),
                phrases: [
                    "Add a random meal to my mealplan in \(.applicationName)",
                    "Plan a random meal in \(.applicationName)"
                ],
                shortTitle: "Random Meal",
                systemImageName: "shuffle"
            )

            AppShortcut(
                intent: RemoveMealFromMealplanIntent(),
                phrases: [
                    "Remove \(\.$meal) from mealplan in \(.applicationName)",
                    "Delete \(\.$meal) from mealplan in \(.applicationName)"
                ],
                shortTitle: "Remove Meal",
                systemImageName: "calendar.badge.minus"
            )

            AppShortcut(
                intent: AddGroceryItemIntent(),
                phrases: [
                    "Add a grocery item in \(.applicationName)",
                    "Add something to groceries in \(.applicationName)",
                    "Put something on my grocery list in \(.applicationName)"
                ],
                shortTitle: "Add Grocery",
                systemImageName: "cart.badge.plus"
            )
        }
    }
}
