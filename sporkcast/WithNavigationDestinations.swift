//
//  WithNavigationDestinations.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
import Recipe
import RecipesList
import Environment
import Models
import RecipeTimersList
import Settings
import Design

struct WithNavigationDestinations<Content: View>: View {
    let namespace: Namespace.ID
    let content: () -> Content

    init(namespace: Namespace.ID, @ViewBuilder content: @escaping () -> Content) {
        self.namespace = namespace
        self.content = content
    }

    var body: some View {
        content()
            .navigationDestination(for: AppDestination.self) { dest in
                switch dest {
                    
                case .recipes:
                    RecipeListPage()
                case let .recipe(recipe, suffix):
                    RecipePage(recipe)
                        .navigationTransition(.zoom(
                            sourceID: "zoom-\(recipe.id.uuidString)\(suffix != nil ? "-\(suffix!)" : "")",
                            in: namespace
                        ))
                }
            }
    }
}

extension View {
    func appSheet(
        _ presented: Binding<AppSheet?>,
        alarmManager: RecipeTimerStore,
        alertManager: AlertManager
    ) -> some View {
        sheet(item: presented) { sheet in
            sheetView(for: sheet, alarmManager: alarmManager, alertManager: alertManager)
        }
    }
    
    @ViewBuilder
    private func sheetView(
        for sheet: AppSheet,
        alarmManager: RecipeTimerStore,
        alertManager: AlertManager
    ) -> some View {
        switch sheet {
        case .timersView:
            RecipeTimersListView()
                .environment(alarmManager)
                .presentationDetents([.medium, .large])
        case .householdSettings:
            NavigationStack {
                HouseholdSettingsPage()
                    .environment(alarmManager)
            }
            
        case .recipeEdit(recipe: let recipe):
            NavigationStack {
                EditRecipePage(recipe: recipe)
                    .environment(alertManager)
            }
        }
    }
}
