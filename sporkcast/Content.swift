//
//  Content.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//

import SwiftUI
import API
import Environment
import AlarmKit
import RecipeTimersList
import RecipesList
import Recipe
import Design
internal import AppRouter

struct AppContent: View {
    @Namespace private var appRouterNamespace
    
    @State private var appRouter = AppRouter(initialTab: .recipes)
    @State private var alarmManager = RecipeTimerStore.shared
    
    @State private var alerting: RecipeTimerRowModel?
    @State private var showAlert = false
    
    var body: some View {
        TabScaffold {
            NavigationStack(path: $appRouter[.recipes]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    RecipeListPage()
                }
            }
        } testRecipe: {
            NavigationStack(path: $appRouter[.testRecipe]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    RecipePage()
                }
            }
        }
        .environment(appRouter)
        .environment(\.networkClient, APIClient(host: "https://api.dev.recipe.tomk.online/"))
        .environment(alarmManager)
        .environment(ZoomManager(appRouterNamespace))
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.white)
        .onOpenURL(prefersInApp: true)
        .sheet(item: $appRouter.presentedSheet) { sheet in
            switch sheet {
            case .timersView:
                RecipeTimersListView()
                    .environment(alarmManager)
                    .presentationDetents([.medium, .large])
            }
        }
        .tabViewBottomAccessory { bottomAccessory }
        .onChange(of: alarmManager.timers, initial: true) { _, newValue in
            if let first = newValue.first(where: { $0.alarmState == .alerting }) {
                alerting = first
                showAlert = true
            }
        }
        .alert(
            alerting?.metadata.title ?? alerting?.title ?? "Timer",
            isPresented: $showAlert
        ) {
            Button("Stop Timer") {
                Task {
                    if let id = alerting?.id {
                        await alarmManager.cancel(id)
                    }
                }
            }
        } message: {
            Text(alerting?.metadata.description ?? "")
        }
    }
    
    @ViewBuilder
    private var bottomAccessory: some View {
        if let first = alarmManager.timers.first {
            TimerAccessoryView(first: first, totalAlarms: alarmManager.timers.count)
                .environment(alarmManager)
                .environment(appRouter)
                .id(alarmManager.timers.count)
        } else {
            EmptyView()
        }
    }
}
