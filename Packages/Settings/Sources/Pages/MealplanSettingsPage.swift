//
//  MealplanSettingsPage.swift
//  Settings
//

import Design
import Environment
import SwiftUI

struct MealplanSettingsPage: View {
    @Environment(\.appSettings) private var store
    @Environment(\.mealplanCalendarSync) private var calendarSync
    @Environment(\.proAccess) private var proAccess

    @State private var calendars: [CalendarListOption] = []
    @State private var selectedCalendarID: String?
    @State private var snapshot = MealplanCalendarSyncSnapshot()
    @State private var isLoadingCalendars = false
    @State private var isPaywallPresented = false

    private let weekStartOptions: [(weekday: Int, title: String)] = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]

    var body: some View {
        List {
            Section {
                Toggle("Show Mealplan Tab", isOn: store.binding(\.showMealplanPage))
            }

            Section("Display") {
                Toggle("Grey Out Past Days", isOn: store.binding(\.greyOutPastMealplanDays))

                Picker("Week Starts On", selection: store.binding(\.mealplanWeekStartWeekday)) {
                    ForEach(weekStartOptions, id: \.weekday) { option in
                        Text(option.title).tag(option.weekday)
                    }
                }
            }

            Section {
                MealplanCalendarSyncStatusCard(
                    snapshot: snapshot,
                    hasProAccess: proAccess.hasProAccess,
                    isLoading: isLoadingCalendars,
                    connect: connectCalendarSync,
                    showPro: showPaywall
                )

                Picker("iCloud Calendar", selection: $selectedCalendarID) {
                    Text("None").tag(String?.none)
                    ForEach(calendars) { calendar in
                        Text(calendar.title).tag(Optional(calendar.id))
                    }
                }
                .disabled(!proAccess.hasProAccess || isLoadingCalendars)
                .onChange(of: selectedCalendarID) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    updateSelectedCalendar(newValue)
                }

                if let linkedCalendarTitle = snapshot.linkedCalendarTitle {
                    LabeledContent("Linked Calendar", value: linkedCalendarTitle)
                }

                if let lastSyncAt = snapshot.lastSyncAt {
                    LabeledContent("Last Sync", value: lastSyncAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let lastError = snapshot.lastError {
                    Text(lastError)
                        .foregroundStyle(.red)
                }

                Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                    syncNow()
                }
                .disabled(!proAccess.hasProAccess || !snapshot.isEnabled || snapshot.isSyncing)

                Button("Refresh Calendars", systemImage: "arrow.clockwise") {
                    Task { await loadCalendars() }
                }
                .disabled(!proAccess.hasProAccess || isLoadingCalendars)
            } header: {
                Text("Calendar Sync")
            } footer: {
                Text("Sporkast Pro can add each mealplan entry as an all-day event in your iCloud calendar. Select None to disconnect Calendar sync.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mealplan")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .task {
            await loadCalendars()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealplanCalendarSyncDidChange)) { _ in
            Task { await refreshSnapshot() }
        }
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView()
        }
        .onChange(of: proAccess.hasProAccess) { _, _ in
            Task { await loadCalendars() }
        }
    }

    private func connectCalendarSync() {
        guard proAccess.hasProAccess else {
            isPaywallPresented = true
            return
        }

        Task {
            if let selectedCalendarID {
                await calendarSync.connect(to: selectedCalendarID)
            } else if let firstCalendarID = calendars.first?.id {
                await calendarSync.connect(to: firstCalendarID)
            } else {
                await calendarSync.connect()
            }
            await loadCalendars()
        }
    }

    private func showPaywall() {
        isPaywallPresented = true
    }

    private func updateSelectedCalendar(_ calendarID: String?) {
        guard proAccess.hasProAccess else {
            selectedCalendarID = nil
            isPaywallPresented = true
            return
        }

        Task {
            if let calendarID {
                await calendarSync.connect(to: calendarID)
            } else {
                await calendarSync.disconnect()
            }
            await refreshSnapshot()
        }
    }

    private func syncNow() {
        Task {
            await calendarSync.syncNow()
            await refreshSnapshot()
        }
    }

    private func loadCalendars() async {
        isLoadingCalendars = true
        await calendarSync.start()
        calendars = proAccess.hasProAccess ? await calendarSync.availableCalendars() : []
        await refreshSnapshot()
        selectedCalendarID = store.settings.mealplanCalendarSyncEnabled ? store.settings.mealplanCalendarIdentifier : nil
        isLoadingCalendars = false
    }

    private func refreshSnapshot() async {
        snapshot = await calendarSync.snapshot()
    }
}

private struct MealplanCalendarSyncStatusCard: View {
    let snapshot: MealplanCalendarSyncSnapshot
    let hasProAccess: Bool
    let isLoading: Bool
    let connect: () -> Void
    let showPro: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if snapshot.isSyncing || isLoading {
                    ProgressView()
                }
            }

            Button(action: hasProAccess ? connect : showPro) {
                Text(hasProAccess ? actionTitle : "Unlock with Pro")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(hasProAccess && (snapshot.isSyncing || isLoading))
        }
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch snapshot.connectionState {
        case .connected: return "calendar.badge.checkmark"
        case .permissionDenied, .failed: return "calendar.badge.exclamationmark"
        case .proRequired: return "sparkles"
        case .connecting: return "calendar.badge.clock"
        case .disconnected: return hasProAccess ? "calendar.badge.plus" : "lock.fill"
        }
    }

    private var iconColor: Color {
        switch snapshot.connectionState {
        case .connected: return .green
        case .permissionDenied, .failed: return .red
        case .proRequired: return .orange
        case .connecting: return .blue
        case .disconnected: return .secondary
        }
    }

    private var title: String {
        guard hasProAccess else { return "Calendar sync is a Pro feature" }

        switch snapshot.connectionState {
        case .connected: return "Mealplans are syncing"
        case .connecting: return "Connecting Calendar"
        case .permissionDenied: return "Calendar access needed"
        case .proRequired: return "Sporkast Pro required"
        case .failed: return "Calendar sync needs attention"
        case .disconnected: return "Sync mealplans to Calendar"
        }
    }

    private var message: String {
        guard hasProAccess else {
            return "Add planned meals to iCloud Calendar so dinner plans show up anywhere you check your day."
        }

        switch snapshot.connectionState {
        case .connected:
            if let linkedCalendarTitle = snapshot.linkedCalendarTitle {
                return "New and changed mealplans will stay up to date in \(linkedCalendarTitle)."
            }
            return "New and changed mealplans will stay up to date in Calendar."
        case .connecting:
            return "Sporkast is requesting Calendar access and preparing your sync."
        case .permissionDenied:
            return "Allow Calendar access in Settings to keep mealplans synced."
        case .proRequired:
            return "Restore or start Sporkast Pro to enable Calendar sync."
        case .failed:
            return "Check the selected iCloud calendar, then try syncing again."
        case .disconnected:
            return "Choose an iCloud calendar and Sporkast will create all-day events for planned meals."
        }
    }

    private var actionTitle: String {
        switch snapshot.connectionState {
        case .connected: return "Reconnect"
        case .connecting: return "Connecting..."
        case .permissionDenied, .failed: return "Try Again"
        case .proRequired: return "Restore Pro"
        case .disconnected: return "Set Up Calendar Sync"
        }
    }
}
