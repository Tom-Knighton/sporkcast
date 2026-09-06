//
//  WithNavigationDestinations.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
import AppIntents
import Recipe
import RecipesList
import Environment
import Models
import RecipeTimersList
import Settings
import Design

struct WithNavigationDestinations<Content: View>: View {
    let namespace: Namespace.ID
    @Binding var pendingSharedImportURL: URL?
    let recipeOrganizationFeatureAccessFallback: Bool
    let socialRecipeImportFeatureAccessFallback: Bool
    let content: () -> Content

    init(
        namespace: Namespace.ID,
        pendingSharedImportURL: Binding<URL?> = .constant(nil),
        recipeOrganizationFeatureAccessFallback: Bool = false,
        socialRecipeImportFeatureAccessFallback: Bool = false,
        @ContentBuilder content: @escaping () -> Content
    ) {
        self.namespace = namespace
        self._pendingSharedImportURL = pendingSharedImportURL
        self.recipeOrganizationFeatureAccessFallback = recipeOrganizationFeatureAccessFallback
        self.socialRecipeImportFeatureAccessFallback = socialRecipeImportFeatureAccessFallback
        self.content = content
    }

    var body: some View {
        content()
            .navigationDestination(for: AppDestination.self) { dest in
                switch dest {
                    
                case let .recipes(folderID):
                    RecipeListPage(
                        pendingSharedImportURL: $pendingSharedImportURL,
                        initialFolderID: folderID,
                        recipeOrganizationFeatureAccessFallback: recipeOrganizationFeatureAccessFallback,
                        socialRecipeImportFeatureAccessFallback: socialRecipeImportFeatureAccessFallback
                    )
                case let .recipe(recipe, suffix):
                    contextualRecipePage(recipe: recipe, suffix: suffix)
                }
            }
    }

    @ViewBuilder
    private func contextualRecipePage(recipe: Models.Recipe, suffix: String?) -> some View {
        let mealplanEntryId = suffix.flatMap(UUID.init(uuidString:))
        let page = RecipePage(recipe, mealplanEntryId: mealplanEntryId)
            .navigationTransition(.zoom(
                sourceID: "zoom-\(recipe.id.uuidString)\(suffix != nil ? "-\(suffix!)" : "")",
                in: namespace
            ))

        if #available(iOS 27.0, *) {
            page
                .appEntityIdentifier(EntityIdentifier(for: RecipeEntity.self, identifier: recipe.id))
                .userActivity("online.tomk.sporkcast.view-recipe", element: recipe.id) { recipeId, activity in
                    activity.title = recipe.title
                    activity.targetContentIdentifier = "sporkcast://recipe/\(recipeId.uuidString)"
                    activity.appEntityIdentifier = EntityIdentifier(for: RecipeEntity.self, identifier: recipeId)
                    activity.isEligibleForSearch = true
                    activity.isEligibleForPrediction = true
                }
        } else {
            page
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
    
    @ContentBuilder
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
