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
import Mealplans
internal import AppRouter
import Models
import Settings
import CloudKit

struct AppContent: View {
    @Namespace private var appRouterNamespace
    
    @State private var appRouter: AppRouter
    @State private var alarmManager = RecipeTimerStore.shared
    @State private var alertManager = AlertManager.shared
    @State private var households = HouseholdService.shared
    
    @State private var alerting: RecipeTimerRowModel?
    @State private var showAlert = false
    
    @State private var appSettings = SettingsStore()
    @Environment(\.modelContext) private var context
    
    public init() {
        self._appRouter = State(wrappedValue: AppRouter(initialTab: SettingsStore().settings.preferredLaunchTab))
    }
    
    var body: some View {
        TabScaffold(selection: $appRouter.selectedTab) {
            NavigationStack(path: $appRouter[.recipes]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    RecipeListPage()
                }
            }
        } mealplans: {
            NavigationStack(path: $appRouter[.mealplan]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    MealplanPage()
                }
            }
        } settings: {
            NavigationStack(path: $appRouter[.settings]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    SettingsPage()
                }
            }
        }
        .appSheet($appRouter.presentedSheet, alarmManager: alarmManager, alertManager: alertManager)
        .preferredColorScheme(getColorScheme())
        .tint(Color.primary)
        .environment(appRouter)
        .environment(\.networkClient, APIClient(host: "https://api.dev.recipe.tomk.online/"))
        .environment(alarmManager)
        .environment(ZoomManager(appRouterNamespace))
        .environment(\.homeServices, HouseholdService.shared)
        .environment(alertManager)
        .environment(\.appSettings, appSettings)
        .environment(\.cloudKit, CloudKitGate())
        .tabBarMinimizeBehavior(.onScrollDown)
        .onOpenURL(prefersInApp: true)
        .tabViewBottomAccessoryCompat(isEnabled: !alarmManager.timers.isEmpty) { bottomAccessory }
        .onChange(of: alarmManager.timers, initial: true) { _, newValue in
            if let first = newValue.first(where: { $0.alarmState == .alerting }) {
                alerting = first
                showAlert = true
            }
        }
        .fullScreenCover(item: $households.pendingInvite, content: { invite in
            HomeInvitePage(for: invite)
        })
        .alert(alertManager.title, isPresented: $alertManager.isShowingAlert, actions: {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        }, message: {
            Text(alertManager.message ?? "")
        })
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
        .task(id: households.home?.id) {
            await households.syncEntities()
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

extension AppContent {
    private func getColorScheme() -> ColorScheme? {
        switch self.appSettings.settings.theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

extension CKShare.Metadata: @retroactive Identifiable {
    
}

extension View {
    @ViewBuilder
    func tabViewBottomAccessoryCompat<Accessory: View>(
        isEnabled: Bool,
        @ViewBuilder content: @escaping () -> Accessory
    ) -> some View {
        if #available(iOS 26.1, *) {
            self.tabViewBottomAccessory(isEnabled: isEnabled, content: content)
        } else {
            if isEnabled {
                self.tabViewBottomAccessory(content: content)
            } else {
                self
            }
        }
    }
}
