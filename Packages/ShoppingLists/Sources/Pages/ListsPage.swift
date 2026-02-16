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
    
    @FetchOne(DBShoppingList.full.where({ !$0.isArchived })) var dbList: FullDBShoppingList?
    private var shoppingList: ShoppingList? {
        dbList?.toDomain()
    }
    
    public init() {
        
    }
    
    public var body: some View {
        ZStack {
            if let shoppingList {
                List {
                    Text(shoppingList.title)
                }
            } else {
                ContentUnavailableView("Create a shopping list", systemImage: "cart.badge.plus", description: Text("Create a shopping list from your meals, and sync it with your reminders."))
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
        let lists = [
            DBShoppingList(id: UUID(), homeId: nil, title: "Shopping List A", createdAt: today, modifiedAt: today, isArchived: false)
        ]
        
        do {
            try db.write { db in
                try DBShoppingList.insert { lists }.execute(db)
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
}
