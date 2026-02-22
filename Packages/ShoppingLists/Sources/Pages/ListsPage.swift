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
    @Environment(\.colorScheme) private var scheme
    @Dependency(\.defaultDatabase) private var db
    @FetchOne(DBShoppingList.full.where({ list, _ in !list.isArchived })) var dbList: FullDBShoppingList?
    @FocusState private var focusedRow: String?
    
    @State private var shoppingList: ShoppingList?
    
    public init() {
        
    }
    
    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()
            if let shoppingList {
                let hasItems = !shoppingList.itemGroups.flatMap(\.items).isEmpty
                let showEmpty = !hasItems && focusedRow == nil
                
                ZStack {
                    
                    listSections(for: Binding($shoppingList)!, focusedField: $focusedRow)
                        .opacity(showEmpty ? 0 : 1)              // hide list visually
                        .allowsHitTesting(!showEmpty)            // prevent taps/scroll
                        .accessibilityHidden(showEmpty)          // avoid VO reading hidden rows
                        .overlay {
                            if showEmpty {
                                noItems()
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: showEmpty)
                }
                .fontDesign(.rounded)
            } else {
                self.noShoppingList()
            }
        }
        .navigationTitle(shoppingList?.title ?? "Shopping")
        .navigationBarTitleDisplayMode(.large)
        .fontDesign(.rounded)
        .onChange(of: dbList, initial: true) { _, newValue in
            if let newValue {
                self.shoppingList = newValue.toDomain()
            } else {
                self.shoppingList = nil
            }
        }
        .safeAreaBar(edge: .bottom, content: {
            HStack {
                Spacer()
                Button(action: { withAnimation { self.focusedRow = "addrow-other"} }) {
                    Image(systemName: "plus")
                        .bold()
                        .font(.title2)
                        .padding(6)
                        .foregroundStyle(.foreground)
                }
                .frame(width: 44, height: 44)
                .buttonBorderShape(.circle)
                .buttonStyle(.glassProminent)
                .tint(scheme == .dark ? .black : .white)
            }
            .scenePadding()
        })
        //        .toolbar {
        //            ToolbarItem {
        //                Button(action: {}) {
        //                    Image(systemName: "plus")
        //                }
        //            }
        //            ToolbarSpacer()
        //            ToolbarItem {
        //                Button(role: .destructive) {
        //
        //                } label: { Image(systemName: "trash")}
        //            }
        //        }
    }
}

extension ShoppingListsPage {
    
    @ViewBuilder
    private func listSections(for list: Binding<ShoppingList>, focusedField: FocusState<String?>.Binding) -> some View {
        ScrollView {
            VStack {
                ForEach(list.itemGroups) { $section in
                    ListSection(section: $section, focusedRow: focusedField)
                    Divider()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }
}


extension ShoppingListsPage {
    
    @ViewBuilder
    private func noShoppingList() -> some View {
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
    
    @ViewBuilder
    private func noItems() -> some View {
        GeometryReader { reader in
            ScrollView {
                VStack {
                    ContentUnavailableView("No Items", systemImage: "fork.knife", description: Text("Items added here will be automatically categorised into groups to help you shop."))
                }
                .frame(height: reader.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
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
        
        let items: [DBShoppingListItem] = [
            DBShoppingListItem(id: UUID(), title: "Chicken Mince", listId: listId, isComplete: false, categoryIdentifier: "meat", categoryDisplayName: "Meat", categorySource: "manual"),
            DBShoppingListItem(id: UUID(), title: "Mince", listId: listId, isComplete: false, categoryIdentifier: "meat", categoryDisplayName: "Meat", categorySource: "manual"),
            DBShoppingListItem(id: UUID(), title: "Chicken Thighs", listId: listId, isComplete: false, categoryIdentifier: "meat", categoryDisplayName: "Meat", categorySource: "manual"),
            DBShoppingListItem(id: UUID(), title: "Carrots", listId: listId, isComplete: false, categoryIdentifier: "vegetables", categoryDisplayName: "Vegetables", categorySource: "manual")
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
    
    TabView {
        Tab {
            NavigationStack {
                ShoppingListsPage()
            }
            .environment(AppRouter(initialTab: .mealplan))
            .environment(ZoomManager(zm))
            .environment(\.homeServices, MockHouseholdService(withHome: false))
        } label: {
            Label("Tab", systemImage: "plus")
        }
    }
}
