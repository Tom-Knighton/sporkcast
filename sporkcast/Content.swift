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
import ShoppingLists

struct AppContent: View {
    private let appGroupSuiteName = "group.sporkcast"
    private let sharedImportURLDefaultsKey = "share.recipeImportURL.v1"

    @Namespace private var appRouterNamespace
    
    @State private var appRouter: AppRouter
    @State private var alarmManager = RecipeTimerStore.shared
    @State private var alertManager = AlertManager.shared
    @State private var households = HouseholdService.shared
    @State private var shoppingMutations = ShoppingListMutationRepository()
    @State private var flagKit: FlagService
    
    @State private var alerting: RecipeTimerRowModel?
    @State private var showAlert = false
    
    @State private var appSettings = SettingsStore()
    @State private var apiClient = APIClient(host: "https://api.dev.sporkast.tomk.online/")
    @State private var cloudKitGate = CloudKitGate()
    @State private var pendingSharedImportURL: URL?
    @State private var lastRoutedSharedImport: (url: String, at: Date)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.shoppingListRemindersSync) private var shoppingListRemindersSync
    
    public init() {
        self._appRouter = State(wrappedValue: AppRouter(initialTab: SettingsStore().settings.preferredLaunchTab))
        self.flagKit = .init(mobileKey: "mob-0e75d9dd-fb2e-4080-b627-83dfaf403079", subscriptionTier: "free")
    }
    
    var body: some View {
        TabScaffold(selection: $appRouter.selectedTab) {
            NavigationStack(path: $appRouter[.recipes]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    RecipeListPage(pendingSharedImportURL: $pendingSharedImportURL)
                }
            }
        } mealplans: {
            NavigationStack(path: $appRouter[.mealplan]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    MealplanPage()
                }
            }
        } shoppingLists: {
            NavigationStack(path: $appRouter[.shoppingLists]) {
                WithNavigationDestinations(namespace: appRouterNamespace) {
                    ShoppingListsPage()
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
//        .tint(Color.primary)
        .environment(appRouter)
        .environment(\.networkClient, apiClient)
        .environment(alarmManager)
        .environment(ZoomManager(appRouterNamespace))
        .environment(\.homeServices, HouseholdService.shared)
        .environment(alertManager)
        .environment(\.appSettings, appSettings)
        .environment(\.cloudKit, cloudKitGate)
        .environment(\.shoppingListMutations, shoppingMutations)
        .environment(\.flagKit, flagKit)
        .tabBarMinimizeBehavior(flagKit.isEnabled(.appCollapseTabBar, default: false) ? .onScrollDown : .automatic)
        .onOpenURL(prefersInApp: true)
        .onOpenURL { incomingURL in
            handleIncomingURL(incomingURL)
        }
        .task {
            if let sharedURL = consumePendingSharedImportURLFromDefaults() {
                routeToRecipeImport(url: sharedURL)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
                  let sharedURL = consumePendingSharedImportURLFromDefaults() else {
                return
            }
            routeToRecipeImport(url: sharedURL)
        }
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
        .task {
            flagKit.start()
            await shoppingListRemindersSync.start()
            let syncSnapshot = await shoppingListRemindersSync.snapshot()
            if syncSnapshot.isEnabled {
                await shoppingListRemindersSync.scheduleSync(trigger: .appLaunch)
            }
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

    private func handleIncomingURL(_ incomingURL: URL) {
        guard incomingURL.scheme?.lowercased() == "sporkcast",
              incomingURL.host == "import-recipe" else {
            return
        }

        if let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
           let sharedURLString = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let sharedURL = URL(string: sharedURLString),
           let scheme = sharedURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            clearPendingSharedImportURLFromDefaults()
            routeToRecipeImport(url: sharedURL)
            return
        }

        guard let sharedURL = consumePendingSharedImportURLFromDefaults() else { return }
        routeToRecipeImport(url: sharedURL)
    }

    private func routeToRecipeImport(url: URL) {
        let absoluteURL = url.absoluteString
        if let lastRoutedSharedImport,
           lastRoutedSharedImport.url == absoluteURL,
           Date().timeIntervalSince(lastRoutedSharedImport.at) < 5 {
            return
        }

        lastRoutedSharedImport = (absoluteURL, Date())
        appRouter.selectedTab = .recipes
        pendingSharedImportURL = url
    }

    private func consumePendingSharedImportURLFromDefaults() -> URL? {
        guard let defaults = UserDefaults(suiteName: appGroupSuiteName),
              let sharedURLString = defaults.string(forKey: sharedImportURLDefaultsKey) else {
            return nil
        }

        defaults.removeObject(forKey: sharedImportURLDefaultsKey)

        guard let sharedURL = URL(string: sharedURLString),
              let scheme = sharedURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return sharedURL
    }

    private func clearPendingSharedImportURLFromDefaults() {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.removeObject(forKey: sharedImportURLDefaultsKey)
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
