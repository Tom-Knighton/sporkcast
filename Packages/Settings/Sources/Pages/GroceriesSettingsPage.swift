//
//  GroceriesSettingsPage.swift
//  Settings
//

import Design
import Environment
import SwiftUI

struct GroceriesSettingsPage: View {
    @Environment(\.appSettings) private var store
    @Environment(\.shoppingListRemindersSync) private var remindersSync

    @State private var reminderLists: [ReminderListOption] = []
    @State private var selectedReminderListID: String?
    @State private var snapshot = ShoppingListRemindersSyncSnapshot()
    @State private var isLoadingReminderLists = false

    var body: some View {
        List {
            Section {
                Toggle("Show Groceries Tab", isOn: store.binding(\.showGroceriesPage))
            }

            Section {
                if isLoadingReminderLists {
                    ProgressView()
                }

                Picker("iCloud List", selection: $selectedReminderListID) {
                    Text("None").tag(String?.none)
                    ForEach(reminderLists) { list in
                        Text(list.title).tag(Optional(list.id))
                    }
                }
                .disabled(isLoadingReminderLists)
                .onChange(of: selectedReminderListID) { _, newValue in
                    Task {
                        if let newValue {
                            await remindersSync.connect(to: newValue)
                        } else {
                            await remindersSync.disconnect()
                        }
                        await refreshSnapshot()
                    }
                }

                if let linkedCalendarTitle = snapshot.linkedCalendarTitle {
                    LabeledContent("Linked List", value: linkedCalendarTitle)
                }

                if let lastError = snapshot.lastError {
                    Text(lastError)
                        .foregroundStyle(.red)
                }

                Button("Refresh Lists", systemImage: "arrow.clockwise") {
                    Task { await loadReminderLists() }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Choose the Reminders list Sporkast syncs groceries to. Select None to disconnect Reminders sync.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Groceries")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .task {
            await loadReminderLists()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shoppingListRemindersSyncDidChange)) { _ in
            Task { await refreshSnapshot() }
        }
    }

    private func loadReminderLists() async {
        isLoadingReminderLists = true
        await remindersSync.start()
        reminderLists = await remindersSync.availableReminderLists()
        await refreshSnapshot()
        selectedReminderListID = store.settings.remindersSyncEnabled ? store.settings.remindersCalendarIdentifier : nil
        isLoadingReminderLists = false
    }

    private func refreshSnapshot() async {
        snapshot = await remindersSync.snapshot()
    }
}
