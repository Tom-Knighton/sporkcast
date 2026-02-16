//
//  ListsPage.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 15/02/2026.
//

import SwiftUI
import Models
import Persistence
import SQLiteData
import Environment
import Design

public struct ShoppingListsPage: View {
    
    @Environment(\.homeServices) private var homes
    @Dependency(\.defaultDatabase) private var db
    @FetchOne(DBShoppingList.full.where({ list, _ in !list.isArchived })) var dbList: FullDBShoppingList?
    private var shoppingList: ShoppingList? {
        dbList?.toDomain()
    }
    
    public init() {
        
    }
    
    public var body: some View {
        ZStack {
            if let shoppingList {
                List {
                    ForEach(shoppingList.items) { item in
                        Text(item.title)
                    }
                }
            } else {
                VStack {
                    ContentUnavailableView {
                        Label("Create a shopping list", systemImage: "cart.badge.plus")
                    } description: {
                        Text("Create a shopping list from your meaks, and sync it with your reminders")
                    } actions: {
                        Button(action: {
                            let homeId = homes.home?.id
                            Task {
                                try await db.write { [homeId] db in
                                    try DBShoppingList.insert {
                                        DBShoppingList(id: UUID(), homeId: homeId, title: "Shopping List", createdAt: Date(), modifiedAt: Date(), isArchived: false)
                                    }
                                    .execute(db)
                                }
                            }
                        }) {
                            Text("Create")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                        .tint(.blue)
                    }
                }
                
            }
            
        }
        .navigationTitle("Shopping")
        .toolbar {
            ToolbarItem {
                Button(action: {}) {
                    Image(systemName: "plus")
                }
            }
            ToolbarSpacer()
            ToolbarItem {
                Button(role: .destructive) {
                    
                } label: { Image(systemName: "trash")}
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var zm
    let today = Calendar(identifier: .iso8601).startOfDay(for: .now)
    let recipeId = UUID()
    
    let _ = PreviewSupport.preparePreviewDatabase(seed: { db in
        let now = Date()
        let listId = UUID()
        let lists = [
            DBShoppingList(id: listId, homeId: nil, title: "Shopping List A", createdAt: today, modifiedAt: today, isArchived: false)
        ]
        
        let items = [
            DBShoppingListItem(id: UUID(), title: "Chicken", listId: listId, isComplete: false, categoryIdentifier: "meat", categoryDisplayName: "Meat", categorySource: "manual")
        ]
        
        do {
            try db.write { db in
                try DBShoppingList.insert { lists }.execute(db)
                try DBShoppingListItem.insert { items }.execute(db)
            }
        } catch {
            print("Preview DB setup failed: \(error)")
        }
    })
    
    NavigationStack {
        ShoppingListsPage()
    }
    .environment(AppRouter(initialTab: .mealplan))
    .environment(ZoomManager(zm))
    .environment(\.homeServices, MockHouseholdService(withHome: false))
}
