import Dependencies
import EventKit
import Foundation
import Models
import Persistence
import SQLiteData

public enum MealplanCalendarSyncTrigger: Sendable {
    case appLaunch
    case localMutation
    case manual
    case eventStoreChanged
}

public struct MealplanCalendarSyncSnapshot: Sendable, Equatable {
    public enum ConnectionState: String, Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case permissionDenied
        case proRequired
        case failed
    }

    public var isEnabled: Bool
    public var isSyncing: Bool
    public var connectionState: ConnectionState
    public var linkedCalendarTitle: String?
    public var lastSyncAt: Date?
    public var lastError: String?

    public init(
        isEnabled: Bool = false,
        isSyncing: Bool = false,
        connectionState: ConnectionState = .disconnected,
        linkedCalendarTitle: String? = nil,
        lastSyncAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.isSyncing = isSyncing
        self.connectionState = connectionState
        self.linkedCalendarTitle = linkedCalendarTitle
        self.lastSyncAt = lastSyncAt
        self.lastError = lastError
    }
}

public struct CalendarListOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String

    public init(id: String, title: String, sourceTitle: String) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
    }
}

public protocol MealplanCalendarSyncing: Sendable {
    func start() async
    func snapshot() async -> MealplanCalendarSyncSnapshot
    func availableCalendars() async -> [CalendarListOption]
    func connect() async
    func connect(to calendarIdentifier: String) async
    func disconnect() async
    func syncNow() async
    func scheduleSync(trigger: MealplanCalendarSyncTrigger) async
    func prepareForLocalEntryDeletion(entryIDs: [UUID]) async throws
}

public extension Notification.Name {
    static let mealplanCalendarSyncDidChange = Notification.Name("mealplanCalendarSyncDidChange")
}

public actor MealplanCalendarSyncService: MealplanCalendarSyncing {

    public static let shared = MealplanCalendarSyncService()
    public static let proAccessDefaultsKey = "access.mealplanCalendarSyncPro.v1"

    @Dependency(\.defaultDatabase) private var database

    private let eventStore = EKEventStore()
    private let syncCalendarTitle = "Sporkast Mealplans"
    private let syncWindowPastDays = 30
    private let syncWindowFutureDays = 370

    private var hasStarted = false
    private var eventStoreObserver: NSObjectProtocol?
    private var localMutationDebounceTask: Task<Void, Never>?

    private var isSyncInProgress = false
    private var hasQueuedSync = false

    private var currentSnapshot = MealplanCalendarSyncSnapshot()

    public init() {}

    public static func setProAccess(_ hasAccess: Bool) {
        UserDefaults.appGroup.set(hasAccess, forKey: proAccessDefaultsKey)
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
                await MealplanCalendarSyncService.shared.scheduleSync(trigger: .eventStoreChanged)
            }
        }

        await refreshSnapshotFromSettings()
    }

    public func snapshot() async -> MealplanCalendarSyncSnapshot {
        currentSnapshot
    }

    public func availableCalendars() async -> [CalendarListOption] {
        guard hasProAccess() else {
            currentSnapshot.connectionState = .proRequired
            currentSnapshot.lastError = "Sporkast Pro is required to sync mealplans to Calendar."
            publishSnapshot()
            return []
        }

        do {
            guard try await requestCalendarAccess() else { return [] }
            return eventStore
                .calendars(for: .event)
                .filter(\.allowsContentModifications)
                .filter { calendar in
                    calendar.source.sourceType == .calDAV
                        || calendar.source.title.localizedCaseInsensitiveContains("icloud")
                }
                .map {
                    CalendarListOption(
                        id: $0.calendarIdentifier,
                        title: $0.title,
                        sourceTitle: $0.source.title
                    )
                }
                .sorted { lhs, rhs in
                    lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
        } catch {
            currentSnapshot.lastError = "Failed to load calendars: \(error.localizedDescription)"
            publishSnapshot()
            return []
        }
    }

    public func connect() async {
        currentSnapshot.connectionState = .connecting
        currentSnapshot.lastError = nil
        publishSnapshot()

        guard hasProAccess() else {
            await disableSyncForProRequirement()
            return
        }

        do {
            let granted = try await requestCalendarAccess()
            guard granted else {
                await updateSettings { settings in
                    settings.mealplanCalendarSyncEnabled = false
                }
                currentSnapshot.connectionState = .permissionDenied
                currentSnapshot.isEnabled = false
                currentSnapshot.lastError = "Calendar access was denied."
                publishSnapshot()
                return
            }

            let calendar = try ensureManagedCalendar()
            let settings = loadSettings()
            if settings.mealplanCalendarIdentifier != calendar.calendarIdentifier {
                try await removeLinkedEvents(using: settings)
            }

            await updateSettings { settings in
                settings.mealplanCalendarSyncEnabled = true
                settings.mealplanCalendarIdentifier = calendar.calendarIdentifier
            }

            currentSnapshot.isEnabled = true
            currentSnapshot.connectionState = .connected
            currentSnapshot.linkedCalendarTitle = calendar.title
            currentSnapshot.lastError = nil
            publishSnapshot()

            await enqueueSync()
        } catch {
            currentSnapshot.isEnabled = false
            currentSnapshot.connectionState = .failed
            currentSnapshot.lastError = "Failed to connect Calendar: \(error.localizedDescription)"
            publishSnapshot()
        }
    }

    public func connect(to calendarIdentifier: String) async {
        currentSnapshot.connectionState = .connecting
        currentSnapshot.lastError = nil
        publishSnapshot()

        guard hasProAccess() else {
            await disableSyncForProRequirement()
            return
        }

        do {
            let granted = try await requestCalendarAccess()
            guard granted else {
                await updateSettings { settings in
                    settings.mealplanCalendarSyncEnabled = false
                }
                currentSnapshot.connectionState = .permissionDenied
                currentSnapshot.isEnabled = false
                currentSnapshot.lastError = "Calendar access was denied."
                publishSnapshot()
                return
            }

            guard let calendar = eventStore.calendar(withIdentifier: calendarIdentifier),
                  calendar.allowsContentModifications else {
                currentSnapshot.connectionState = .failed
                currentSnapshot.lastError = "Unable to find the selected Calendar."
                publishSnapshot()
                return
            }

            let settings = loadSettings()
            if settings.mealplanCalendarIdentifier != calendar.calendarIdentifier {
                try await removeLinkedEvents(using: settings)
                try removeManagedCalendarOrphans(excluding: calendar)
            }

            await updateSettings { settings in
                settings.mealplanCalendarSyncEnabled = true
                settings.mealplanCalendarIdentifier = calendar.calendarIdentifier
            }

            currentSnapshot.isEnabled = true
            currentSnapshot.connectionState = .connected
            currentSnapshot.linkedCalendarTitle = calendar.title
            currentSnapshot.lastError = nil
            publishSnapshot()

            await enqueueSync()
        } catch {
            currentSnapshot.isEnabled = false
            currentSnapshot.connectionState = .failed
            currentSnapshot.lastError = "Failed to connect Calendar: \(error.localizedDescription)"
            publishSnapshot()
        }
    }

    public func disconnect() async {
        localMutationDebounceTask?.cancel()
        localMutationDebounceTask = nil

        do {
            try await removeLinkedEvents(using: loadSettings())
        } catch {
            currentSnapshot.lastError = "Failed to remove synced Calendar events: \(error.localizedDescription)"
        }

        await updateSettings { settings in
            settings.mealplanCalendarSyncEnabled = false
            settings.mealplanCalendarIdentifier = nil
        }

        currentSnapshot.isEnabled = false
        currentSnapshot.isSyncing = false
        currentSnapshot.connectionState = .disconnected
        currentSnapshot.linkedCalendarTitle = nil
        currentSnapshot.lastError = nil
        publishSnapshot()
    }

    public func syncNow() async {
        await enqueueSync()
    }

    public func scheduleSync(trigger: MealplanCalendarSyncTrigger) async {
        let settings = loadSettings()
        guard settings.mealplanCalendarSyncEnabled else { return }
        guard hasProAccess() else {
            currentSnapshot.isEnabled = false
            currentSnapshot.connectionState = .proRequired
            currentSnapshot.lastError = "Sporkast Pro is required to keep mealplans synced to Calendar."
            publishSnapshot()
            return
        }

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

    public func prepareForLocalEntryDeletion(entryIDs: [UUID]) async throws {
        guard !entryIDs.isEmpty else { return }

        let settings = loadSettings()
        guard settings.mealplanCalendarSyncEnabled, hasProAccess() else { return }

        let granted = try await requestCalendarAccess()
        guard granted else { return }

        guard let calendar = try await resolveLinkedCalendar(using: settings) else { return }

        let links = try await database.read { db in
            try DBMealplanEntryCalendarEventLink
                .where { entryIDs.contains($0.mealplanEntryId) }
                .fetchAll(db)
        }

        guard !links.isEmpty else { return }

        for link in links {
            if let event = eventStore.calendarItem(withIdentifier: link.eventIdentifier) as? EKEvent,
               event.calendar.calendarIdentifier == calendar.calendarIdentifier {
                try eventStore.remove(event, span: .thisEvent, commit: true)
            }
        }
    }
}

private extension MealplanCalendarSyncService {

    struct LocalState {
        let entries: [FullDBMealplanEntry]
        let links: [DBMealplanEntryCalendarEventLink]
    }

    struct LinkUpdate {
        let id: UUID
        let eventIdentifier: String
        let eventExternalIdentifier: String?
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
            guard settings.mealplanCalendarSyncEnabled else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .disconnected
                currentSnapshot.lastError = nil
                return
            }

            guard hasProAccess() else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .proRequired
                currentSnapshot.lastError = "Sporkast Pro is required to keep mealplans synced to Calendar."
                return
            }

            let granted = try await requestCalendarAccess()
            guard granted else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .permissionDenied
                currentSnapshot.lastError = "Calendar access is required to sync mealplans."
                return
            }

            guard let calendar = try await resolveLinkedCalendar(using: settings) else {
                currentSnapshot.isEnabled = false
                currentSnapshot.connectionState = .failed
                currentSnapshot.lastError = "Unable to find or create the linked Calendar."
                return
            }

            let localState = try await loadLocalState()
            try await reconcile(localState: localState, calendar: calendar)

            currentSnapshot.isEnabled = true
            currentSnapshot.connectionState = .connected
            currentSnapshot.linkedCalendarTitle = calendar.title
            currentSnapshot.lastError = nil
            currentSnapshot.lastSyncAt = Date()
        } catch {
            currentSnapshot.connectionState = .failed
            currentSnapshot.lastError = "Mealplan calendar sync failed: \(error.localizedDescription)"
        }
    }

    func reconcile(localState: LocalState, calendar: EKCalendar) async throws {
        let now = Date()
        try removeManagedCalendarOrphans(excluding: calendar)

        let localEntryIDs = Set(localState.entries.map(\.mealplanEntry.id))
        var linksByLocalID: [UUID: DBMealplanEntryCalendarEventLink] = [:]
        for link in localState.links where linksByLocalID[link.mealplanEntryId] == nil {
            linksByLocalID[link.mealplanEntryId] = link
        }
        let events = eventsForSyncWindow(in: calendar)
        var eventsByIdentifier: [String: EKEvent] = [:]
        for event in events where eventsByIdentifier[event.calendarItemIdentifier] == nil {
            eventsByIdentifier[event.calendarItemIdentifier] = event
        }
        var eventsByExternalIdentifier: [String: [EKEvent]] = [:]

        for event in events {
            guard let externalIdentifier = event.calendarItemExternalIdentifier else { continue }
            eventsByExternalIdentifier[externalIdentifier, default: []].append(event)
        }

        var linkDeletes: Set<UUID> = []
        var linkUpdates: [LinkUpdate] = []
        var linkInserts: [DBMealplanEntryCalendarEventLink] = []

        for link in localState.links where !localEntryIDs.contains(link.mealplanEntryId) {
            if let event = eventForLink(
                link,
                eventsByIdentifier: eventsByIdentifier,
                eventsByExternalIdentifier: eventsByExternalIdentifier
            ) {
                try eventStore.remove(event, span: .thisEvent, commit: true)
            }
            linkDeletes.insert(link.id)
        }

        for entry in localState.entries {
            let title = eventTitle(for: entry)
            guard !title.isEmpty else { continue }

            if let link = linksByLocalID[entry.mealplanEntry.id] {
                if let event = eventForLink(
                    link,
                    eventsByIdentifier: eventsByIdentifier,
                    eventsByExternalIdentifier: eventsByExternalIdentifier
                ) {
                    apply(entry: entry, title: title, to: event, calendar: calendar)
                    try eventStore.save(event, span: .thisEvent, commit: true)

                    if event.calendarItemIdentifier != link.eventIdentifier ||
                        event.calendarItemExternalIdentifier != link.eventExternalIdentifier {
                        linkUpdates.append(
                            LinkUpdate(
                                id: link.id,
                                eventIdentifier: event.calendarItemIdentifier,
                                eventExternalIdentifier: event.calendarItemExternalIdentifier,
                                lastSyncedAt: now
                            )
                        )
                    }
                    continue
                }

                linkDeletes.insert(link.id)
            }

            let event = EKEvent(eventStore: eventStore)
            apply(entry: entry, title: title, to: event, calendar: calendar)
            try eventStore.save(event, span: .thisEvent, commit: true)

            linkInserts.append(
                DBMealplanEntryCalendarEventLink(
                    id: UUID(),
                    mealplanEntryId: entry.mealplanEntry.id,
                    eventIdentifier: event.calendarItemIdentifier,
                    eventExternalIdentifier: event.calendarItemExternalIdentifier,
                    lastSyncedAt: now
                )
            )
        }

        guard !linkDeletes.isEmpty || !linkUpdates.isEmpty || !linkInserts.isEmpty else { return }

        let linkDeletesSnapshot = linkDeletes
        let linkUpdatesSnapshot = linkUpdates
        let linkInsertsSnapshot = linkInserts

        try await database.write { db in
            for linkID in linkDeletesSnapshot {
                try DBMealplanEntryCalendarEventLink.find(linkID).delete().execute(db)
            }

            for update in linkUpdatesSnapshot {
                try DBMealplanEntryCalendarEventLink.find(update.id).update {
                    $0.eventIdentifier = update.eventIdentifier
                    $0.eventExternalIdentifier = update.eventExternalIdentifier
                    $0.lastSyncedAt = update.lastSyncedAt
                }
                .execute(db)
            }

            if !linkInsertsSnapshot.isEmpty {
                try DBMealplanEntryCalendarEventLink.insert { linkInsertsSnapshot }.execute(db)
            }
        }
    }

    func apply(entry: FullDBMealplanEntry, title: String, to event: EKEvent, calendar: EKCalendar) {
        let startOfDay = Calendar.current.startOfDay(for: entry.mealplanEntry.date)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)

        event.calendar = calendar
        event.title = title
        event.isAllDay = true
        event.startDate = startOfDay
        event.endDate = endDate
        event.url = URL(string: "sporkcast://mealplan")
        event.notes = eventNotes(for: entry)
    }

    func eventTitle(for entry: FullDBMealplanEntry) -> String {
        if let recipeTitle = entry.recipe?.title.trimmingCharacters(in: .whitespacesAndNewlines),
           !recipeTitle.isEmpty {
            return recipeTitle
        }

        return entry.mealplanEntry.noteText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Meal planned in Sporkast"
    }

    func eventNotes(for entry: FullDBMealplanEntry) -> String {
        var lines = ["Synced from Sporkast mealplans."]

        if let note = entry.mealplanEntry.noteText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty,
           entry.recipe != nil {
            lines.append("")
            lines.append(note)
        }

        if let sourceURL = entry.recipe?.sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceURL.isEmpty {
            lines.append("")
            lines.append(sourceURL)
        }

        return lines.joined(separator: "\n")
    }

    func eventForLink(
        _ link: DBMealplanEntryCalendarEventLink,
        eventsByIdentifier: [String: EKEvent],
        eventsByExternalIdentifier: [String: [EKEvent]]
    ) -> EKEvent? {
        if let direct = eventsByIdentifier[link.eventIdentifier] {
            return direct
        }

        if let external = link.eventExternalIdentifier,
           let candidates = eventsByExternalIdentifier[external],
           candidates.count == 1 {
            return candidates[0]
        }

        return nil
    }

    func loadLocalState() async throws -> LocalState {
        try await database.read { db in
            let entries = try DBMealplanEntry.full.fetchAll(db)
            let links = try DBMealplanEntryCalendarEventLink.fetchAll(db)
            return LocalState(entries: entries, links: links)
        }
    }

    func eventsForSyncWindow(in calendar: EKCalendar) -> [EKEvent] {
        let startDate = Calendar.current.date(byAdding: .day, value: -syncWindowPastDays, to: .now) ?? .now
        let endDate = Calendar.current.date(byAdding: .day, value: syncWindowFutureDays, to: .now) ?? .now
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        return eventStore.events(matching: predicate)
    }

    func removeLinkedEvents(using settings: AppSettings) async throws {
        guard let calendarIdentifier = settings.mealplanCalendarIdentifier,
              let calendar = eventStore.calendar(withIdentifier: calendarIdentifier),
              calendar.allowsContentModifications else {
            return
        }

        let links = try await database.read { db in
            try DBMealplanEntryCalendarEventLink.fetchAll(db)
        }

        for link in links {
            if let event = eventStore.calendarItem(withIdentifier: link.eventIdentifier) as? EKEvent,
               event.calendar.calendarIdentifier == calendar.calendarIdentifier {
                try eventStore.remove(event, span: .thisEvent, commit: true)
            }
        }
    }

    func removeManagedCalendarOrphans(excluding selectedCalendar: EKCalendar) throws {
        guard selectedCalendar.title != syncCalendarTitle,
              let managedCalendar = eventStore
                .calendars(for: .event)
                .first(where: { $0.title == syncCalendarTitle && $0.allowsContentModifications }) else {
            return
        }

        let events = eventsForSyncWindow(in: managedCalendar)
        for event in events where event.notes?.contains("Synced from Sporkast mealplans.") == true {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        }
    }

    func requestCalendarAccess() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .writeOnly:
            return false
        case .authorized:
            return true
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, error in
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
            .calendars(for: .event)
            .first(where: { $0.title == syncCalendarTitle && $0.allowsContentModifications }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = syncCalendarTitle

        if let iCloudSource = eventStore.sources.first(where: {
            $0.sourceType == .calDAV || $0.title.localizedCaseInsensitiveContains("icloud")
        }) {
            calendar.source = iCloudSource
        } else if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = defaultSource
        } else if let firstSource = eventStore.sources.first {
            calendar.source = firstSource
        } else {
            throw NSError(
                domain: "MealplanCalendarSyncService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No calendar source is available."]
            )
        }

        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    func resolveLinkedCalendar(using settings: AppSettings) async throws -> EKCalendar? {
        if let identifier = settings.mealplanCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: identifier),
           calendar.allowsContentModifications {
            return calendar
        }

        let calendar = try ensureManagedCalendar()
        await updateSettings { settings in
            settings.mealplanCalendarIdentifier = calendar.calendarIdentifier
            settings.mealplanCalendarSyncEnabled = true
        }
        return calendar
    }

    func refreshSnapshotFromSettings() async {
        let settings = loadSettings()
        currentSnapshot.isEnabled = settings.mealplanCalendarSyncEnabled

        if settings.mealplanCalendarSyncEnabled && !hasProAccess() {
            currentSnapshot.connectionState = .proRequired
            currentSnapshot.lastError = "Sporkast Pro is required to sync mealplans to Calendar."
        } else {
            currentSnapshot.connectionState = settings.mealplanCalendarSyncEnabled ? .connected : .disconnected
            currentSnapshot.lastError = nil
        }

        if let identifier = settings.mealplanCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: identifier) {
            currentSnapshot.linkedCalendarTitle = calendar.title
        } else {
            currentSnapshot.linkedCalendarTitle = nil
        }

        publishSnapshot()
    }

    func disableSyncForProRequirement() async {
        await updateSettings { settings in
            settings.mealplanCalendarSyncEnabled = false
        }

        currentSnapshot.isEnabled = false
        currentSnapshot.connectionState = .proRequired
        currentSnapshot.lastError = "Sporkast Pro is required to sync mealplans to Calendar."
        publishSnapshot()
    }

    func hasProAccess() -> Bool {
        UserDefaults.appGroup.object(forKey: Self.proAccessDefaultsKey) as? Bool ?? false
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

        currentSnapshot.isEnabled = settings.mealplanCalendarSyncEnabled
        if !settings.mealplanCalendarSyncEnabled {
            currentSnapshot.connectionState = .disconnected
            currentSnapshot.linkedCalendarTitle = nil
        }
        publishSnapshot()
    }

    func publishSnapshot() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .mealplanCalendarSyncDidChange, object: nil)
        }
    }
}
