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

private struct AutoAssignedMoveToast: Identifiable, Equatable {
    let id = UUID()
    let itemID: UUID
    let fromCategory: ShoppingCategory
    let toCategory: ShoppingCategory
}

public struct ShoppingListsPage: View {
    @Environment(\.homeServices) private var homes
    @Environment(\.colorScheme) private var scheme
    @Dependency(\.defaultDatabase) private var db
    @FetchOne(DBShoppingList.full.where({ list, _ in !list.isArchived })) private var dbList: FullDBShoppingList?
    @FetchAll(DBShoppingListItem.all) private var dbClassifierItems: [DBShoppingListItem]
    @FocusState private var focusedRow: String?

    @State private var shoppingList: ShoppingList?
    @State private var pendingCompletionRemovals: Set<UUID> = []
    @State private var pendingCompletionRemovalTokens: [UUID: UUID] = [:]
    @State private var reclassificationSuggestions: [UUID: ShoppingCategory] = [:]
    @State private var revealedInputSectionID: String?
    @State private var autoAssignedMoveToast: AutoAssignedMoveToast?

    private let classifier = ShoppingCategoryClassifier()

    public init() {

    }

    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()

            if let shoppingList {
                let sections = displayedSections(for: shoppingList)
                let showEmpty = sections.isEmpty

                listSections(sections: sections, focusedField: $focusedRow)
                    .opacity(showEmpty ? 0 : 1)
                    .allowsHitTesting(!showEmpty)
                    .accessibilityHidden(showEmpty)
                    .overlay {
                        if showEmpty {
                            noItems()
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showEmpty)
                    .fontDesign(.rounded)
            } else {
                noShoppingList()
            }
        }
        .navigationTitle(shoppingList?.title ?? "Shopping")
        .navigationBarTitleDisplayMode(.large)
        .fontDesign(.rounded)
        .onChange(of: dbList, initial: true) { _, newValue in
            updateShoppingListState(from: newValue)
        }
        .onDisappear {
            revealedInputSectionID = nil
            autoAssignedMoveToast = nil
        }
        .safeAreaBar(edge: .bottom, content: {
            HStack {
                Spacer()
                Button("Add Item", systemImage: "plus", action: focusUnknownInputRow)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Add item")
                    .bold()
                    .font(.title2)
                    .padding(6)
                    .foregroundStyle(.foreground)
                    .frame(width: 44, height: 44)
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glassProminent)
                    .tint(scheme == .dark ? .black : .white)
            }
            .scenePadding()
        })
        .overlay(alignment: .bottom) {
            if let autoAssignedMoveToast {
                ShoppingListAutoMoveToastView(
                    message: "Moved to \(autoAssignedMoveToast.toCategory.displayName)",
                    onUndo: { undoAutoAssignedMove(autoAssignedMoveToast) }
                )
                .padding(.bottom, 72)
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: autoAssignedMoveToast)
    }
}

private extension ShoppingListsPage {

    @ViewBuilder
    func listSections(sections: [ShoppingListItemGroup], focusedField: FocusState<String?>.Binding) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 12) {
                    ForEach(sections) { section in
                        ShoppingListSectionView(
                            section: section,
                            focusedRow: focusedField,
                            pendingCompletionRemovals: pendingCompletionRemovals,
                            reclassificationSuggestions: reclassificationSuggestions,
                            onToggleCompletion: completeItem(_:),
                            onSubmitTitle: updateItemTitle(_:to:),
                            onSubmitNewItem: addItem(in:title:),
                            onAcceptSuggestion: acceptSuggestion(for:category:),
                            onDropItem: { itemID, category in
                                moveItem(id: itemID, to: category, source: "manual")
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    @ViewBuilder
    func noShoppingList() -> some View {
        VStack {
            ContentUnavailableView {
                Label("Create a shopping list", systemImage: "cart.badge.plus")
            } description: {
                Text("Create a shopping list from your meals, and sync it with your reminders")
            } actions: {
                Button("Create", action: createShoppingList)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.glassProminent)
                    .buttonSizing(.flexible)
                    .tint(.blue)
            }
        }
    }

    @ViewBuilder
    func noItems() -> some View {
        GeometryReader { reader in
            ScrollView {
                VStack {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "fork.knife",
                        description: Text("Items added here will be automatically categorised into groups to help you shop.")
                    )
                }
                .frame(height: reader.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private extension ShoppingListsPage {

    func sortedSections(for list: ShoppingList) -> [ShoppingListItemGroup] {
        list.itemGroups.sorted { lhs, rhs in
            let leftCategory = ShoppingCategory(categoryIdentifier: lhs.id)
            let rightCategory = ShoppingCategory(categoryIdentifier: rhs.id)

            if leftCategory.sortOrder != rightCategory.sortOrder {
                return leftCategory.sortOrder < rightCategory.sortOrder
            }

            let leftName = lhs.names.first ?? leftCategory.displayName
            let rightName = rhs.names.first ?? rightCategory.displayName
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
    }

    func displayedSections(for list: ShoppingList) -> [ShoppingListItemGroup] {
        sortedSections(for: list).filter { section in
            let hasVisibleItems = !visibleItems(in: section).isEmpty
            let isFocusedInputSection = focusedRow == "addrow-\(section.id)"
            let isRevealedInputSection = revealedInputSectionID == section.id
            return hasVisibleItems || isFocusedInputSection || isRevealedInputSection
        }
    }

    func visibleItems(in section: ShoppingListItemGroup) -> [ShoppingListItem] {
        section.items.filter { item in
            !item.isComplete || pendingCompletionRemovals.contains(item.id)
        }
    }

    func classifierContextItems() -> [ShoppingListItem] {
        guard !dbClassifierItems.isEmpty else {
            return shoppingList?.itemGroups.flatMap(\.items) ?? []
        }

        var bestItemsByKey: [String: DBShoppingListItem] = [:]
        bestItemsByKey.reserveCapacity(dbClassifierItems.count)

        for item in dbClassifierItems {
            let normalizedTitle = item.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalizedTitle.isEmpty else { continue }

            let categoryIdentifier = item.categoryIdentifier ?? ShoppingCategory.unknown.rawValue
            let key = "\(categoryIdentifier)|\(normalizedTitle)"

            if let existing = bestItemsByKey[key],
               classifierSourcePriority(item.categorySource) <= classifierSourcePriority(existing.categorySource) {
                continue
            }

            bestItemsByKey[key] = item
        }

        return bestItemsByKey.values.map { dbItem in
            ShoppingListItem(
                id: dbItem.id,
                title: dbItem.title,
                isComplete: dbItem.isComplete,
                categoryId: dbItem.categoryIdentifier ?? ShoppingCategory.unknown.rawValue,
                categoryName: dbItem.categoryDisplayName,
                categorySource: dbItem.categorySource
            )
        }
    }

    func classifierSourcePriority(_ source: String) -> Int {
        switch source.lowercased() {
        case "manual", "suggestion":
            return 3
        case "classifier":
            return 1
        default:
            return 2
        }
    }

    func focusUnknownInputRow() {
        withAnimation {
            revealedInputSectionID = ShoppingCategory.unknown.rawValue
        }

        Task { @MainActor in
            await Task.yield()
            focusedRow = "addrow-unknown"
        }
    }

    func createShoppingList() {
        let homeId = homes.home?.id
        Task {
            do {
                try await db.write { [homeId] db in
                    try DBShoppingList.insert {
                        DBShoppingList(
                            id: UUID(),
                            homeId: homeId,
                            title: "Shopping List",
                            createdAt: Date(),
                            modifiedAt: Date(),
                            isArchived: false
                        )
                    }
                    .execute(db)
                }
            } catch {
                print("Failed to create shopping list: \(error)")
            }
        }
    }

    func updateShoppingListState(from newValue: FullDBShoppingList?) {
        guard let newValue else {
            shoppingList = nil
            pendingCompletionRemovals.removeAll()
            pendingCompletionRemovalTokens.removeAll()
            reclassificationSuggestions.removeAll()
            revealedInputSectionID = nil
            autoAssignedMoveToast = nil
            return
        }

        let domainList = newValue.toDomain()
        shoppingList = domainList

        let itemsById = Dictionary(uniqueKeysWithValues: domainList.itemGroups.flatMap(\.items).map { ($0.id, $0) })
        let validIds = Set(itemsById.keys)

        pendingCompletionRemovals = pendingCompletionRemovals.intersection(validIds)
        pendingCompletionRemovalTokens = pendingCompletionRemovalTokens.filter { itemId, _ in
            validIds.contains(itemId) && pendingCompletionRemovals.contains(itemId)
        }
        reclassificationSuggestions = reclassificationSuggestions.filter { itemId, suggestedCategory in
            guard let item = itemsById[itemId] else { return false }
            return ShoppingCategory(categoryIdentifier: item.categoryId) != suggestedCategory
        }

        if let autoAssignedMoveToast, !validIds.contains(autoAssignedMoveToast.itemID) {
            self.autoAssignedMoveToast = nil
        }
    }

    func addItem(in section: ShoppingListItemGroup, title: String) {
        guard let listId = shoppingList?.id else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let fallbackCategory = ShoppingCategory(categoryIdentifier: section.id)
        let inferredCategory = classifier.classify(
            trimmedTitle,
            fallback: fallbackCategory,
            knownItems: classifierContextItems()
        )
        let shouldAutoMove = fallbackCategory == .unknown && inferredCategory != .unknown
        let assignedCategory = shouldAutoMove ? inferredCategory : fallbackCategory
        let assignedSource = shouldAutoMove ? "classifier" : "manual"
        let itemID = UUID()

        Task {
            do {
                try await db.write { db in
                    try DBShoppingListItem.insert {
                        DBShoppingListItem(
                            id: itemID,
                            title: trimmedTitle,
                            listId: listId,
                            isComplete: false,
                            categoryIdentifier: assignedCategory.rawValue,
                            categoryDisplayName: assignedCategory.displayName,
                            categorySource: assignedSource
                        )
                    }
                    .execute(db)

                    try DBShoppingList.find(listId).update {
                        $0.modifiedAt = Date()
                    }
                    .execute(db)
                }

                if shouldAutoMove {
                    await MainActor.run {
                        showAutoAssignedMoveToast(
                            itemID: itemID,
                            fromCategory: fallbackCategory,
                            toCategory: inferredCategory
                        )
                    }
                } else if inferredCategory != .unknown && inferredCategory != fallbackCategory {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reclassificationSuggestions[itemID] = inferredCategory
                        }
                    }
                }
            } catch {
                print("Failed to add shopping list item: \(error)")
            }
        }
    }

    func updateItemTitle(_ item: ShoppingListItem, to newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let currentCategory = ShoppingCategory(categoryIdentifier: item.categoryId)
        let inferredCategory = classifier.classify(
            trimmedTitle,
            fallback: .unknown,
            knownItems: classifierContextItems()
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            if inferredCategory != .unknown && inferredCategory != currentCategory {
                reclassificationSuggestions[item.id] = inferredCategory
            } else {
                reclassificationSuggestions[item.id] = nil
            }
        }

        guard item.title != trimmedTitle else { return }
        let listId = shoppingList?.id

        Task {
            do {
                try await db.write { db in
                    try DBShoppingListItem.find(item.id).update {
                        $0.title = trimmedTitle
                    }
                    .execute(db)

                    if let listId {
                        try DBShoppingList.find(listId).update {
                            $0.modifiedAt = Date()
                        }
                        .execute(db)
                    }
                }
            } catch {
                print("Failed to update shopping list item title: \(error)")
            }
        }
    }

    func completeItem(_ item: ShoppingListItem) {
        let listId = shoppingList?.id
        let itemID = item.id

        if item.isComplete {
            cancelPendingCompletionRemoval(for: itemID)

            Task {
                do {
                    try await db.write { db in
                        try DBShoppingListItem.find(itemID).update {
                            $0.isComplete = false
                        }
                        .execute(db)

                        if let listId {
                            try DBShoppingList.find(listId).update {
                                $0.modifiedAt = Date()
                            }
                            .execute(db)
                        }
                    }

                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = pendingCompletionRemovals.remove(itemID)
                        }
                    }
                } catch {
                    await MainActor.run {
                        schedulePendingCompletionRemoval(for: itemID)
                    }
                    print("Failed to mark shopping list item incomplete: \(error)")
                }
            }

            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            _ = pendingCompletionRemovals.insert(itemID)
        }
        schedulePendingCompletionRemoval(for: itemID)

        Task {
            do {
                try await db.write { db in
                    try DBShoppingListItem.find(itemID).update {
                        $0.isComplete = true
                    }
                    .execute(db)

                    if let listId {
                        try DBShoppingList.find(listId).update {
                            $0.modifiedAt = Date()
                        }
                        .execute(db)
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = pendingCompletionRemovals.remove(itemID)
                    }
                    cancelPendingCompletionRemoval(for: itemID)
                }
                print("Failed to mark shopping list item complete: \(error)")
            }
        }
    }

    func acceptSuggestion(for item: ShoppingListItem, category: ShoppingCategory) {
        _ = moveItem(id: item.id, to: category, source: "suggestion")
    }

    @discardableResult
    func moveItem(id itemId: UUID, to category: ShoppingCategory, source: String) -> Bool {
        guard let item = shoppingList?.itemGroups.flatMap(\.items).first(where: { $0.id == itemId }) else {
            return false
        }

        let currentCategory = ShoppingCategory(categoryIdentifier: item.categoryId)
        guard currentCategory != category else {
            return false
        }

        let listId = shoppingList?.id

        withAnimation(.easeInOut(duration: 0.2)) {
            reclassificationSuggestions[itemId] = nil
        }

        Task {
            do {
                try await db.write { db in
                    try DBShoppingListItem.find(itemId).update {
                        $0.categoryIdentifier = category.rawValue
                        $0.categoryDisplayName = category.displayName
                        $0.categorySource = source
                    }
                    .execute(db)

                    if let listId {
                        try DBShoppingList.find(listId).update {
                            $0.modifiedAt = Date()
                        }
                        .execute(db)
                    }
                }
            } catch {
                print("Failed to move shopping list item: \(error)")
            }
        }

        return true
    }

    func schedulePendingCompletionRemoval(for itemID: UUID) {
        let token = UUID()
        pendingCompletionRemovalTokens[itemID] = token

        Task { [itemID, token] in
            try? await Task.sleep(for: .milliseconds(2200))
            await MainActor.run {
                guard pendingCompletionRemovalTokens[itemID] == token else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    pendingCompletionRemovals.remove(itemID)
                    reclassificationSuggestions[itemID] = nil
                }
                pendingCompletionRemovalTokens[itemID] = nil
            }
        }
    }

    func cancelPendingCompletionRemoval(for itemID: UUID) {
        pendingCompletionRemovalTokens[itemID] = nil
    }

    func showAutoAssignedMoveToast(
        itemID: UUID,
        fromCategory: ShoppingCategory,
        toCategory: ShoppingCategory
    ) {
        let toast = AutoAssignedMoveToast(
            itemID: itemID,
            fromCategory: fromCategory,
            toCategory: toCategory
        )

        autoAssignedMoveToast = toast

        Task { [toastID = toast.id] in
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                if autoAssignedMoveToast?.id == toastID {
                    autoAssignedMoveToast = nil
                }
            }
        }
    }

    func undoAutoAssignedMove(_ toast: AutoAssignedMoveToast) {
        autoAssignedMoveToast = nil
        let listId = shoppingList?.id

        Task {
            do {
                try await db.write { db in
                    try DBShoppingListItem.find(toast.itemID).update {
                        $0.categoryIdentifier = toast.fromCategory.rawValue
                        $0.categoryDisplayName = toast.fromCategory.displayName
                        $0.categorySource = "manual"
                    }
                    .execute(db)

                    if let listId {
                        try DBShoppingList.find(listId).update {
                            $0.modifiedAt = Date()
                        }
                        .execute(db)
                    }
                }
            } catch {
                print("Failed to undo shopping list auto move: \(error)")
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var zm
    let today = Calendar(identifier: .iso8601).startOfDay(for: .now)

    let _ = PreviewSupport.preparePreviewDatabase(seed: { db in
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
