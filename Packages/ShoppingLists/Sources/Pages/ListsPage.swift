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
    @Environment(\.shoppingListMutations) private var shoppingMutations
    @Environment(\.shoppingListRemindersSync) private var remindersSync
    @FetchAll(DBShoppingList.full.where({ list, _ in !list.isArchived })) private var dbLists: [FullDBShoppingList]
    @FetchAll(DBShoppingListItem.all) private var dbClassifierItems: [DBShoppingListItem]
    @FocusState private var focusedRow: String?

    private let classifier = ShoppingCategoryClassifier()

    @State private var shoppingList: ShoppingList?
    @State private var pendingCompletionRemovals: Set<UUID> = []
    @State private var pendingCompletionRemovalTokens: [UUID: UUID] = [:]
    @State private var reclassificationSuggestions: [UUID: ShoppingCategory] = [:]
    @State private var revealedInputSectionID: String?
    @State private var autoAssignedMoveToast: AutoAssignedMoveToast?
    @State private var remindersSnapshot = ShoppingListRemindersSyncSnapshot()
    @State private var showGroceriesSetupPrompt = false

    private var pageTitle: String {
        shoppingList?.title ?? "Shopping"
    }

    public init() {

    }

    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()

            if let shoppingList {
                let sections = displayedSections(for: shoppingList)
                let showEmpty = sections.isEmpty

                ShoppingListSectionsView(
                    sections: sections,
                    focusedRow: $focusedRow,
                    reclassificationSuggestions: reclassificationSuggestions,
                    remindersSnapshot: remindersSnapshot,
                    onSyncNow: syncRemindersNowAction,
                    onToggleCompletion: completeItem(_:),
                    onSubmitTitle: updateItemTitle(_:to:),
                    onSubmitNewItem: addItem(in:title:),
                    onAcceptSuggestion: acceptSuggestion(for:category:),
                    onDropItem: { itemID, category in
                        moveItem(id: itemID, to: category, source: "manual")
                    }
                )
                    .opacity(showEmpty ? 0 : 1)
                    .allowsHitTesting(!showEmpty)
                    .accessibilityHidden(showEmpty)
                    .overlay {
                        if showEmpty {
                            ShoppingListNoItemsView()
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showEmpty)
                    .fontDesign(.rounded)
            } else {
                ShoppingListNoListView(onCreate: createShoppingList)
            }
        }
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.large)
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItem {
                ShoppingListToolbarMenuView(
                    isSyncEnabled: remindersSnapshot.isEnabled,
                    lastSyncAt: remindersSnapshot.lastSyncAt,
                    lastError: remindersSnapshot.lastError,
                    canClearList: shoppingList != nil,
                    onSyncNow: syncRemindersNowAction,
                    onConnectReminders: connectRemindersAction,
                    onDisconnectReminders: disconnectRemindersAction,
                    onClearList: clearListAction
                )
            }
        }
        .onChange(of: dbLists, initial: true) { _, newValue in
            Task { @MainActor in
                updateShoppingListState(from: preferredShoppingList(from: newValue))
            }
        }
        .onDisappear {
            revealedInputSectionID = nil
            autoAssignedMoveToast = nil
        }
        .task {
            await remindersSync.start()
            await remindersSync.scheduleSync(trigger: .shoppingTabAppeared)
            await refreshRemindersSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shoppingListRemindersSyncDidChange)) { _ in
            Task { await refreshRemindersSnapshot() }
        }
        .onChange(of: remindersSnapshot.needsGroceriesSetupPrompt, initial: true) { _, needsPrompt in
            if needsPrompt {
                showGroceriesSetupPrompt = true
            }
        }
        .safeAreaBar(edge: .bottom, content: {
            ShoppingListAddItemBarView(
                scheme: scheme,
                onAddItem: focusUnknownInputRow
            )
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
        .sheet(isPresented: $showGroceriesSetupPrompt) {
            ShoppingListGroceriesSetupPromptView(
                isPresented: $showGroceriesSetupPrompt,
                onAcknowledge: acknowledgeGroceriesSetupPrompt
            )
        }
        .animation(.easeInOut(duration: 0.2), value: autoAssignedMoveToast)
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

    func preferredShoppingList(from lists: [FullDBShoppingList]) -> FullDBShoppingList? {
        guard !lists.isEmpty else { return nil }

        let sorted = lists.sorted { lhs, rhs in
            let left = lhs.shoppingList
            let right = rhs.shoppingList
            if left.modifiedAt != right.modifiedAt {
                return left.modifiedAt > right.modifiedAt
            }
            return left.createdAt > right.createdAt
        }

        if let withItems = sorted.first(where: { !$0.items.isEmpty }) {
            return withItems
        }

        return sorted.first
    }

    func displayedSections(for list: ShoppingList) -> [ShoppingListDisplaySection] {
        let sectionsWithVisibleItems = sortedSections(for: list).map { section in
            (section: section, visibleItems: visibleItems(in: section))
        }
        let hasAnyVisibleItems = sectionsWithVisibleItems.contains { !$0.visibleItems.isEmpty }

        return sectionsWithVisibleItems.compactMap { entry in
            let section = entry.section
            let hasVisibleItems = !entry.visibleItems.isEmpty
            let isFocusedInputSection = focusedRow == "addrow-\(section.id)"
            let isRevealedInputSection = revealedInputSectionID == section.id
            let isDefaultEmptySection = !hasAnyVisibleItems && ShoppingCategory(categoryIdentifier: section.id) == .unknown
            if hasVisibleItems || isFocusedInputSection || isRevealedInputSection || isDefaultEmptySection {
                return ShoppingListDisplaySection(
                    section: section,
                    visibleItems: entry.visibleItems
                )
            } else {
                return nil
            }
        }
    }

    func visibleItems(in section: ShoppingListItemGroup) -> [ShoppingListItem] {
        section.items.filter { item in
            !item.isComplete || pendingCompletionRemovals.contains(item.id)
        }
    }

    // MARK: - View Actions

    func focusUnknownInputRow() {
        withAnimation {
            revealedInputSectionID = ShoppingCategory.unknown.rawValue
        }

        Task { @MainActor in
            await Task.yield()
            focusedRow = "addrow-unknown"
        }
    }

    func connectRemindersAction() {
        Task { await connectReminders() }
    }

    func disconnectRemindersAction() {
        Task { await disconnectReminders() }
    }

    func syncRemindersNowAction() {
        Task { await syncRemindersNow() }
    }

    func clearListAction() {
        Task { await clearList() }
    }

    func acknowledgeGroceriesSetupPrompt() {
        Task {
            await remindersSync.markGroceriesSetupPromptShown()
            await refreshRemindersSnapshot()
            showGroceriesSetupPrompt = false
        }
    }

    // MARK: - Reminders Sync

    @MainActor
    func refreshRemindersSnapshot() async {
        remindersSnapshot = await remindersSync.snapshot()
    }

    func connectReminders() async {
        await remindersSync.connect()
        await refreshRemindersSnapshot()
    }

    func disconnectReminders() async {
        await remindersSync.disconnect()
        await refreshRemindersSnapshot()
    }

    func syncRemindersNow() async {
        await remindersSync.syncNow()
        await refreshRemindersSnapshot()
    }

    // MARK: - Shopping List Mutations

    func createShoppingList() {
        let homeId = homes.home?.id
        Task {
            do {
                _ = try await shoppingMutations.ensureActiveShoppingList(homeId: homeId)
            } catch {
                print("Failed to create shopping list: \(error)")
            }
        }
    }

    @MainActor
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
            knownItems: ShoppingListClassifierContextBuilder.contextItems(
                dbItems: dbClassifierItems,
                fallbackList: shoppingList
            )
        )
        let shouldAutoMove = fallbackCategory == .unknown && inferredCategory != .unknown
        let assignedCategory = shouldAutoMove ? inferredCategory : fallbackCategory
        let assignedSource = shouldAutoMove ? "classifier" : "manual"

        Task {
            do {
                let itemID = try await shoppingMutations.addItem(
                    listId: listId,
                    title: trimmedTitle,
                    isComplete: false,
                    category: assignedCategory,
                    categorySource: assignedSource
                )

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
            knownItems: ShoppingListClassifierContextBuilder.contextItems(
                dbItems: dbClassifierItems,
                fallbackList: shoppingList
            )
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
                try await shoppingMutations.updateItemTitle(
                    itemId: item.id,
                    listId: listId,
                    title: trimmedTitle
                )
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
                    try await shoppingMutations.setItemCompletion(
                        itemId: itemID,
                        listId: listId,
                        isComplete: false
                    )

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
                try await shoppingMutations.setItemCompletion(
                    itemId: itemID,
                    listId: listId,
                    isComplete: true
                )
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
                try await shoppingMutations.updateItemCategory(
                    itemId: itemId,
                    listId: listId,
                    category: category,
                    source: source
                )
            } catch {
                print("Failed to move shopping list item: \(error)")
            }
        }

        return true
    }

    // MARK: - Pending Completion Removal

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

    // MARK: - Auto Move Toast

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
                try await shoppingMutations.updateItemCategory(
                    itemId: toast.itemID,
                    listId: listId,
                    category: toast.fromCategory,
                    source: "manual"
                )
            } catch {
                print("Failed to undo shopping list auto move: \(error)")
            }
        }
    }
}

private extension ShoppingListsPage {
    private func clearList() async {
        guard let listId = shoppingList?.id else { return }
        do {
            try await shoppingMutations.clearList(listId: listId)
        } catch {
            print(error.localizedDescription)
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
