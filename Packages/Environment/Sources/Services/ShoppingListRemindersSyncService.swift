import Dependencies
import EventKit
import Foundation
import Models
import Persistence
import SQLiteData

public enum ShoppingListRemindersSyncTrigger: Sendable {
    case appLaunch
    case shoppingTabAppeared
    case localMutation
    case manual
    case eventStoreChanged
}

public struct ShoppingListRemindersSyncSnapshot: Sendable, Equatable {
    public enum ConnectionState: String, Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case permissionDenied
        case failed
    }

    public var isEnabled: Bool
    public var isSyncing: Bool
    public var connectionState: ConnectionState
    public var linkedCalendarTitle: String?
    public var lastSyncAt: Date?
    public var lastError: String?
    public var needsGroceriesSetupPrompt: Bool

    public init(
        isEnabled: Bool = false,
        isSyncing: Bool = false,
        connectionState: ConnectionState = .disconnected,
        linkedCalendarTitle: String? = nil,
        lastSyncAt: Date? = nil,
        lastError: String? = nil,
        needsGroceriesSetupPrompt: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.isSyncing = isSyncing
        self.connectionState = connectionState
        self.linkedCalendarTitle = linkedCalendarTitle
        self.lastSyncAt = lastSyncAt
        self.lastError = lastError
        self.needsGroceriesSetupPrompt = needsGroceriesSetupPrompt
    }
}

public protocol ShoppingListRemindersSyncing: Sendable {
    func start() async
    func snapshot() async -> ShoppingListRemindersSyncSnapshot
    func connect() async
    func disconnect() async
    func syncNow() async
    func scheduleSync(trigger: ShoppingListRemindersSyncTrigger) async
    func markGroceriesSetupPromptShown() async
    func prepareForLocalItemDeletion(itemIDs: [UUID]) async throws
}

public extension Notification.Name {
    static let shoppingListRemindersSyncDidChange = Notification.Name("shoppingListRemindersSyncDidChange")
}

public actor ShoppingListRemindersSyncService: ShoppingListRemindersSyncing {

    public static let shared = ShoppingListRemindersSyncService()

    @Dependency(\.defaultDatabase) private var database

    private let eventStore = EKEventStore()
    private let classifier = ShoppingCategoryClassifier()
    private let syncListTitle = "Sporkast Shopping"

    private var hasStarted = false
    private var eventStoreObserver: NSObjectProtocol?
    private var localMutationDebounceTask: Task<Void, Never>?

    private var isSyncInProgress = false
    private var hasQueuedSync = false

    private var currentSnapshot = ShoppingListRemindersSyncSnapshot()

    public init() {
        self.currentSnapshot = ShoppingListRemindersSyncSnapshot(
            isEnabled: false,
            isSyncing: false,
            connectionState: .disconnected,
            linkedCalendarTitle: nil,
            lastSyncAt: nil,
            lastError: nil,
            needsGroceriesSetupPrompt: false
        )
    }

    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                await ShoppingListRemindersSyncService.shared.scheduleSync(trigger: .eventStoreChanged)
            }
        }

        await refreshSnapshotFromSettings()
    }

    public func snapshot() async -> ShoppingListRemindersSyncSnapshot {
        currentSnapshot
    }

    public func connect() async {
        currentSnapshot.connectionState = .connecting
        currentSnapshot.lastError = nil
        publishSnapshot()

        do {
            let granted = try await requestReminderAccess()
            guard granted else {
                await updateSettings { settings in
                    settings.remindersSyncEnabled = false
                }
                currentSnapshot.connectionState = .permissionDenied
                currentSnapshot.isEnabled = false
                currentSnapshot.lastError = "Reminders access was denied."
                publishSnapshot()
                return
            }

            let calendar = try ensureManagedCalendar()
            await updateSettings { settings in
                settings.remindersSyncEnabled = true
                settings.remindersCalendarIdentifier = calendar.calendarIdentifier
                settings.remindersNeedsGroceriesSetupPrompt = true
            }

            currentSnapshot.isEnabled = true
            currentSnapshot.connectionState = .connected
            currentSnapshot.linkedCalendarTitle = calendar.title
            currentSnapshot.needsGroceriesSetupPrompt = true
            currentSnapshot.lastError = nil
            publishSnapshot()

            await enqueueSync()
        } catch {
            currentSnapshot.isEnabled = false
            currentSnapshot.connectionState = .failed
            currentSnapshot.lastError = "Failed to connect Reminders: \(error.localizedDescription)"
            publishSnapshot()
        }
    }

    public func disconnect() async {
        localMutationDebounceTask?.cancel()
        localMutationDebounceTask = nil

        await updateSettings { settings in
            settings.remindersSyncEnabled = false
            settings.remindersCalendarIdentifier = nil
            settings.remindersNeedsGroceriesSetupPrompt = false
        }

        currentSnapshot.isEnabled = false
        currentSnapshot.isSyncing = false
        currentSnapshot.connectionState = .disconnected
        currentSnapshot.linkedCalendarTitle = nil
        currentSnapshot.needsGroceriesSetupPrompt = false
        currentSnapshot.lastError = nil
        publishSnapshot()
    }

    public func syncNow() async {
        await enqueueSync()
    }

    public func scheduleSync(trigger: ShoppingListRemindersSyncTrigger) async {
        if trigger == .localMutation {
            localMutationDebounceTask?.cancel()
            localMutationDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                await self.enqueueSync()
            }
            return
        }

        await enqueueSync()
    }

    public func markGroceriesSetupPromptShown() async {
        await updateSettings { settings in
            settings.remindersNeedsGroceriesSetupPrompt = false
        }

        currentSnapshot.needsGroceriesSetupPrompt = false
        publishSnapshot()
    }

    public func prepareForLocalItemDeletion(itemIDs: [UUID]) async throws {
        guard !itemIDs.isEmpty else { return }

        let settings = loadSettings()
        guard settings.remindersSyncEnabled else { return }

        let granted = try await requestReminderAccess()
        guard granted else { return }

        guard let calendar = try await resolveLinkedCalendar(using: settings) else { return }

        let links = try await database.read { db in
            try DBShoppingListItemReminderLink
                .all
                .fetchAll(db)
                .filter { itemIDs.contains($0.shoppingListItemId) }
        }

        guard !links.isEmpty else { return }

        for link in links {
            if let reminder = eventStore.calendarItem(withIdentifier: link.reminderIdentifier) as? EKReminder,
               reminder.calendar.calendarIdentifier == calendar.calendarIdentifier {
                try eventStore.remove(reminder, commit: true)
            }
        }
    }
}

private extension ShoppingListRemindersSyncService {

    struct LocalState {
        let list: DBShoppingList
        let items: [DBShoppingListItem]
        let links: [DBShoppingListItemReminderLink]
    }

    struct ReminderFetchResult: @unchecked Sendable {
        let reminders: [EKReminder]
    }

    struct LocalItemUpdate {
        let id: UUID
        let title: String
        let isComplete: Bool
        let modifiedAt: Date
        let categoryIdentifier: String
        let categoryDisplayName: String
        let categorySource: String
    }

    struct LinkUpdate {
        let id: UUID
        let reminderIdentifier: String
        let reminderExternalIdentifier: String?
        let lastSyncedAt: Date
    }

    func enqueueSync() async {
        hasQueuedSync = true
        guard !isSyncInProgress else { return }

        while hasQueuedSync {
            hasQueuedSync = false
            await performSyncPass()
        }
    }

    func performSyncPass() async {
        isSyncInProgress = true
        currentSnapshot.isSyncing = true
        publishSnapshot()

        defer {
            isSyncInProgress = false
            currentSnapshot.isSyncing = false
            publishSnapshot()
        }

        do {
            let settings = loadSettings()
            guard settings.remindersSyncEnabled else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .disconnected
                currentSnapshot.lastError = nil
                return
            }

            let granted = try await requestReminderAccess()
            guard granted else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .permissionDenied
                currentSnapshot.lastError = "Reminders access is required to sync shopping items."
                return
            }

            guard let calendar = try await resolveLinkedCalendar(using: settings) else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .failed
                currentSnapshot.lastError = "Unable to find or create the linked Reminders list."
                return
            }

            let localState = try await loadLocalState()
            guard let localState else {
                currentSnapshot.isEnabled = true
                currentSnapshot.connectionState = .connected
                currentSnapshot.linkedCalendarTitle = calendar.title
                currentSnapshot.lastError = nil
                currentSnapshot.lastSyncAt = Date()
                return
            }

            let remoteReminders = await fetchReminders(in: calendar)
            try await reconcile(localState: localState, remoteReminders: remoteReminders, calendar: calendar)

            currentSnapshot.isEnabled = true
            currentSnapshot.connectionState = .connected
            currentSnapshot.linkedCalendarTitle = calendar.title
            currentSnapshot.lastError = nil
            currentSnapshot.lastSyncAt = Date()
            currentSnapshot.needsGroceriesSetupPrompt = settings.remindersNeedsGroceriesSetupPrompt
        } catch {
            currentSnapshot.connectionState = .failed
            currentSnapshot.lastError = "Shopping list sync failed: \(error.localizedDescription)"
        }
    }

    func reconcile(localState: LocalState, remoteReminders: [EKReminder], calendar: EKCalendar) async throws {
        let now = Date()
        var localItemsByID = Dictionary(uniqueKeysWithValues: localState.items.map { ($0.id, $0) })
        var linksByLocalID = Dictionary(uniqueKeysWithValues: localState.links.map { ($0.shoppingListItemId, $0) })
        var linksByReminderID = Dictionary(uniqueKeysWithValues: localState.links.map { ($0.reminderIdentifier, $0) })

        let remoteByIdentifier = Dictionary(uniqueKeysWithValues: remoteReminders.map { ($0.calendarItemIdentifier, $0) })
        var remoteByExternalIdentifier: [String: [EKReminder]] = [:]
        for reminder in remoteReminders {
            guard let external = reminder.calendarItemExternalIdentifier else { continue }
            remoteByExternalIdentifier[external, default: []].append(reminder)
        }

        var localDeletes: Set<UUID> = []
        var localUpdates: [LocalItemUpdate] = []
        var localInserts: [DBShoppingListItem] = []

        var linkDeletes: Set<UUID> = []
        var linkUpdates: [LinkUpdate] = []
        var linkInserts: [DBShoppingListItemReminderLink] = []

        var matchedReminderIdentifiers = Set<String>()

        var classifierKnownItems = localState.items.map {
            ShoppingListItem(
                id: $0.id,
                title: $0.title,
                isComplete: $0.isComplete,
                categoryId: $0.categoryIdentifier ?? ShoppingCategory.unknown.rawValue,
                categoryName: $0.categoryDisplayName,
                categorySource: $0.categorySource
            )
        }

        for localItem in localState.items {
            if localDeletes.contains(localItem.id) { continue }

            guard let link = linksByLocalID[localItem.id] else {
                let reminder = EKReminder(eventStore: eventStore)
                reminder.calendar = calendar
                reminder.title = localItem.title
                reminder.isCompleted = localItem.isComplete
                try eventStore.save(reminder, commit: true)

                let linkInsert = DBShoppingListItemReminderLink(
                    id: UUID(),
                    shoppingListItemId: localItem.id,
                    reminderIdentifier: reminder.calendarItemIdentifier,
                    reminderExternalIdentifier: reminder.calendarItemExternalIdentifier,
                    lastSyncedAt: now
                )
                linkInserts.append(linkInsert)
                linksByReminderID[reminder.calendarItemIdentifier] = linkInsert
                matchedReminderIdentifiers.insert(reminder.calendarItemIdentifier)
                continue
            }

            let linkedReminder = remoteForLink(
                link,
                remoteByIdentifier: remoteByIdentifier,
                remoteByExternalIdentifier: remoteByExternalIdentifier
            )

            guard let reminder = linkedReminder else {
                localDeletes.insert(localItem.id)
                linkDeletes.insert(link.id)
                continue
            }

            matchedReminderIdentifiers.insert(reminder.calendarItemIdentifier)

            if reminder.calendarItemIdentifier != link.reminderIdentifier ||
                reminder.calendarItemExternalIdentifier != link.reminderExternalIdentifier {
                linkUpdates.append(
                    LinkUpdate(
                        id: link.id,
                        reminderIdentifier: reminder.calendarItemIdentifier,
                        reminderExternalIdentifier: reminder.calendarItemExternalIdentifier,
                        lastSyncedAt: now
                    )
                )
            }

            let remoteModified = reminder.lastModifiedDate ?? reminder.creationDate ?? .distantPast
            let localModified = localItem.modifiedAt

            if localModified > remoteModified {
                var changedRemote = false
                if reminder.title != localItem.title {
                    reminder.title = localItem.title
                    changedRemote = true
                }
                if reminder.isCompleted != localItem.isComplete {
                    reminder.isCompleted = localItem.isComplete
                    changedRemote = true
                }

                if changedRemote {
                    try eventStore.save(reminder, commit: true)
                }

                linkUpdates.append(
                    LinkUpdate(
                        id: link.id,
                        reminderIdentifier: reminder.calendarItemIdentifier,
                        reminderExternalIdentifier: reminder.calendarItemExternalIdentifier,
                        lastSyncedAt: now
                    )
                )
            } else if remoteModified > localModified {
                let remoteTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !remoteTitle.isEmpty else { continue }

                let currentCategory = ShoppingCategory(categoryIdentifier: localItem.categoryIdentifier ?? ShoppingCategory.unknown.rawValue)
                let inferredCategory = classifier.classify(
                    remoteTitle,
                    fallback: currentCategory,
                    knownItems: classifierKnownItems
                )

                localUpdates.append(
                    LocalItemUpdate(
                        id: localItem.id,
                        title: remoteTitle,
                        isComplete: reminder.isCompleted,
                        modifiedAt: remoteModified,
                        categoryIdentifier: inferredCategory.rawValue,
                        categoryDisplayName: inferredCategory.displayName,
                        categorySource: inferredCategory == currentCategory ? localItem.categorySource : "classifier"
                    )
                )

                classifierKnownItems.removeAll { $0.id == localItem.id }
                classifierKnownItems.append(
                    ShoppingListItem(
                        id: localItem.id,
                        title: remoteTitle,
                        isComplete: reminder.isCompleted,
                        categoryId: inferredCategory.rawValue,
                        categoryName: inferredCategory.displayName,
                        categorySource: inferredCategory == currentCategory ? localItem.categorySource : "classifier"
                    )
                )
            }
        }

        for reminder in remoteReminders {
            if matchedReminderIdentifiers.contains(reminder.calendarItemIdentifier) {
                continue
            }

            if let linked = linksByReminderID[reminder.calendarItemIdentifier] {
                if localItemsByID[linked.shoppingListItemId] == nil {
                    linkDeletes.insert(linked.id)
                }
                continue
            }

            let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let itemID = UUID()
            let inferredCategory = classifier.classify(
                title,
                fallback: .unknown,
                knownItems: classifierKnownItems
            )

            let remoteModified = reminder.lastModifiedDate ?? reminder.creationDate ?? now
            let item = DBShoppingListItem(
                id: itemID,
                title: title,
                listId: localState.list.id,
                isComplete: reminder.isCompleted,
                modifiedAt: remoteModified,
                categoryIdentifier: inferredCategory.rawValue,
                categoryDisplayName: inferredCategory.displayName,
                categorySource: "classifier"
            )
            localInserts.append(item)
            localItemsByID[itemID] = item

            classifierKnownItems.append(
                ShoppingListItem(
                    id: itemID,
                    title: title,
                    isComplete: reminder.isCompleted,
                    categoryId: inferredCategory.rawValue,
                    categoryName: inferredCategory.displayName,
                    categorySource: "classifier"
                )
            )

            let link = DBShoppingListItemReminderLink(
                id: UUID(),
                shoppingListItemId: itemID,
                reminderIdentifier: reminder.calendarItemIdentifier,
                reminderExternalIdentifier: reminder.calendarItemExternalIdentifier,
                lastSyncedAt: now
            )
            linkInserts.append(link)
            linksByLocalID[itemID] = link
        }

        let hadLocalMutations = !localDeletes.isEmpty || !localUpdates.isEmpty || !localInserts.isEmpty
        let hadLinkMutations = !linkDeletes.isEmpty || !linkUpdates.isEmpty || !linkInserts.isEmpty

        guard hadLocalMutations || hadLinkMutations else { return }

        let localDeletesSnapshot = localDeletes
        let localUpdatesSnapshot = localUpdates
        let localInsertsSnapshot = localInserts
        let linkDeletesSnapshot = linkDeletes
        let linkUpdatesSnapshot = linkUpdates
        let linkInsertsSnapshot = linkInserts
        let listID = localState.list.id

        try await database.write { db in
            for localID in localDeletesSnapshot {
                try DBShoppingListItem.find(localID).delete().execute(db)
            }

            for update in localUpdatesSnapshot {
                try DBShoppingListItem.find(update.id).update {
                    $0.title = update.title
                    $0.isComplete = update.isComplete
                    $0.modifiedAt = update.modifiedAt
                    $0.categoryIdentifier = #bind(update.categoryIdentifier)
                    $0.categoryDisplayName = update.categoryDisplayName
                    $0.categorySource = update.categorySource
                }
                .execute(db)
            }

            if !localInsertsSnapshot.isEmpty {
                try DBShoppingListItem.insert { localInsertsSnapshot }.execute(db)
            }

            for linkID in linkDeletesSnapshot {
                try DBShoppingListItemReminderLink.find(linkID).delete().execute(db)
            }

            for update in linkUpdatesSnapshot {
                try DBShoppingListItemReminderLink.find(update.id).update {
                    $0.reminderIdentifier = update.reminderIdentifier
                    $0.reminderExternalIdentifier = update.reminderExternalIdentifier
                    $0.lastSyncedAt = update.lastSyncedAt
                }
                .execute(db)
            }

            if !linkInsertsSnapshot.isEmpty {
                try DBShoppingListItemReminderLink.insert { linkInsertsSnapshot }.execute(db)
            }

            if hadLocalMutations {
                try DBShoppingList.find(listID).update {
                    $0.modifiedAt = now
                }
                .execute(db)
            }
        }
    }

    func remoteForLink(
        _ link: DBShoppingListItemReminderLink,
        remoteByIdentifier: [String: EKReminder],
        remoteByExternalIdentifier: [String: [EKReminder]]
    ) -> EKReminder? {
        if let direct = remoteByIdentifier[link.reminderIdentifier] {
            return direct
        }

        if let external = link.reminderExternalIdentifier,
           let candidates = remoteByExternalIdentifier[external],
           candidates.count == 1 {
            return candidates[0]
        }

        return nil
    }

    func loadLocalState() async throws -> LocalState? {
        try await database.read { db -> LocalState? in
            let lists = try DBShoppingList
                .where(\.isArchived)
                .not()
                .order(by: \.createdAt)
                .fetchAll(db)

            guard let list = lists.first else { return nil }

            let items = try DBShoppingListItem
                .where { $0.listId.eq(list.id) }
                .fetchAll(db)

            let itemIDs = Set(items.map(\.id))
            let links = try DBShoppingListItemReminderLink
                .all
                .fetchAll(db)
                .filter { itemIDs.contains($0.shoppingListItemId) }

            return LocalState(list: list, items: items, links: links)
        }
    }

    func fetchReminders(in calendar: EKCalendar) async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<ReminderFetchResult, Never>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: ReminderFetchResult(reminders: reminders ?? []))
            }
        }
        return result.reminders
    }

    func requestReminderAccess() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return true
        case .writeOnly:
            return false
        case .authorized:
            return true
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func ensureManagedCalendar() throws -> EKCalendar {
        if let existing = eventStore
            .calendars(for: .reminder)
            .first(where: { $0.title == syncListTitle && $0.allowsContentModifications }) {
            return existing
        }

        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = syncListTitle

        if let source = eventStore.defaultCalendarForNewReminders()?.source {
            calendar.source = source
        } else if let fallbackSource = eventStore.sources.first(where: {
            !$0.calendars(for: .reminder).isEmpty || $0.sourceType == .local
        }) {
            calendar.source = fallbackSource
        } else if let firstSource = eventStore.sources.first {
            calendar.source = firstSource
        } else {
            throw NSError(
                domain: "ShoppingListRemindersSyncService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No reminder source is available."]
            )
        }

        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    func resolveLinkedCalendar(using settings: AppSettings) async throws -> EKCalendar? {
        if let identifier = settings.remindersCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: identifier),
           calendar.allowsContentModifications {
            return calendar
        }

        let calendar = try ensureManagedCalendar()
        await self.updateSettings { settings in
            settings.remindersCalendarIdentifier = calendar.calendarIdentifier
            settings.remindersSyncEnabled = true
            settings.remindersNeedsGroceriesSetupPrompt = true
        }
        return calendar
    }

    func refreshSnapshotFromSettings() async {
        let settings = loadSettings()
        currentSnapshot.isEnabled = settings.remindersSyncEnabled
        currentSnapshot.needsGroceriesSetupPrompt = settings.remindersNeedsGroceriesSetupPrompt
        currentSnapshot.connectionState = settings.remindersSyncEnabled ? .connected : .disconnected

        if let identifier = settings.remindersCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: identifier) {
            currentSnapshot.linkedCalendarTitle = calendar.title
        } else {
            currentSnapshot.linkedCalendarTitle = nil
        }

        publishSnapshot()
    }

    func loadSettings() -> AppSettings {
        let defaults = UserDefaults.appGroup
        let key = "app.settings.v1"

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }

        return decoded
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) async {
        let defaults = UserDefaults.appGroup
        let key = "app.settings.v1"
        var settings = loadSettings()
        mutate(&settings)

        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: key)
        }

        Task { @MainActor in
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }

        currentSnapshot.isEnabled = settings.remindersSyncEnabled
        currentSnapshot.needsGroceriesSetupPrompt = settings.remindersNeedsGroceriesSetupPrompt
        if !settings.remindersSyncEnabled {
            currentSnapshot.connectionState = .disconnected
            currentSnapshot.linkedCalendarTitle = nil
        }
        publishSnapshot()
    }

    func publishSnapshot() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .shoppingListRemindersSyncDidChange, object: nil)
        }
    }
}
