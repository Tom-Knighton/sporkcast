//
//  ShoppingListEmptyStateViews.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI
import Design

struct ShoppingListNoListView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack {
            ContentUnavailableView {
                Label("Create a shopping list", systemImage: "cart.badge.plus")
            } description: {
                Text("Create a shopping list from your meals, and sync it with your reminders")
            } actions: {
                Button("Create", action: onCreate)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.glassProminent)
                    .buttonSizing(.flexible)
                    .tint(.blue)
            }
        }
    }
}

struct ShoppingListNoItemsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Items",
            systemImage: "fork.knife",
            description: Text("Items added here will be automatically categorised into groups to help you shop.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
