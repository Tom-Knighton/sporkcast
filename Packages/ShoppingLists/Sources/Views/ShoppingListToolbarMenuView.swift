//
//  ShoppingListToolbarMenuView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI

struct ShoppingListToolbarMenuView: View {
    let isSyncEnabled: Bool
    let lastSyncAt: Date?
    let lastError: String?
    let canClearList: Bool
    let onSyncNow: () -> Void
    let onConnectReminders: () -> Void
    let onDisconnectReminders: () -> Void
    let onClearList: () -> Void

    var body: some View {
        Menu {
            if isSyncEnabled {
                Button(action: onSyncNow) {
                    Label("Sync Now", systemImage: "arrow.trianglehead.2.clockwise")
                }

                Button(role: .destructive, action: onDisconnectReminders) {
                    Label("Disconnect Reminders", systemImage: "link.badge.minus")
                }
            } else {
                Button(action: onConnectReminders) {
                    Label("Connect Reminders", systemImage: "link.badge.plus")
                }
            }

            if let lastSyncAt {
                Text("Last Sync: \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))")
            }

            if let lastError {
                Text(lastError)
                    .foregroundStyle(.red)
            }

            Divider()
            Button(action: onClearList) {
                Label("Remove All Items", systemImage: "cart.badge.minus.fill")
            }
            .disabled(!canClearList)
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}
