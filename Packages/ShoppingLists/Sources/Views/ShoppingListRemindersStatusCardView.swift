//
//  ShoppingListRemindersStatusCardView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI
import Environment
import Design

struct ShoppingListRemindersStatusCardView: View {
    let snapshot: ShoppingListRemindersSyncSnapshot
    let onSyncNow: () -> Void

    var body: some View {
        if snapshot.isEnabled || snapshot.lastError != nil {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: snapshot.lastError == nil ? "checkmark.icloud.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(snapshot.lastError == nil ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    if snapshot.isEnabled {
                        Text("Reminders Sync On")
                            .font(.headline)

                        if let calendarTitle = snapshot.linkedCalendarTitle {
                            Text("Linked list: \(calendarTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Reminders Sync Off")
                            .font(.headline)
                    }

                    if let lastSync = snapshot.lastSyncAt {
                        Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let lastError = snapshot.lastError {
                        Text(lastError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button("Sync", action: onSyncNow)
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(!snapshot.isEnabled || snapshot.isSyncing)
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
    }
}
