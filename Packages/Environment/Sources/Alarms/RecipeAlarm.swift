//
//  RecipeAlarm.swift
//  Environment
//
//  Created by Tom Knighton on 29/09/2025.
//

import SwiftUI
@preconcurrency import AlarmKit
import Observation
import AppIntents

public struct RecipeTimerMetadata: AlarmMetadata, Codable, Hashable {
    public let title: String
    public let createdAt: Date
    public let colorHex: String
    public let recipeStepId: UUID
    public let stepTimerIndex: Int
    public let recipeId: UUID
    public let description: String?
    
    public init(title: String, createdAt: Date, colorHex: String, recipeStepId: UUID, stepTimerIndex: Int, recipeId: UUID, description: String?) {
        self.title = title
        self.createdAt = createdAt
        self.colorHex = colorHex
        self.recipeStepId = recipeStepId
        self.stepTimerIndex = stepTimerIndex
        self.recipeId = recipeId
        self.description = description
    }
}

public struct RecipeTimerPresentation: Codable, Equatable {
    public enum Mode: Codable, Equatable {
        case countdown(total: TimeInterval, previouslyElapsed: TimeInterval, startDate: Date)
        case paused(total: TimeInterval, previouslyElapsed: TimeInterval)
        case alerting
        case scheduled(fireDate: Date)
    }
    
    public var mode: Mode
}

@Observable
public class RecipeTimerRowModel: Identifiable, Equatable, Codable {
    public static func == (lhs: RecipeTimerRowModel, rhs: RecipeTimerRowModel) -> Bool {
        lhs.id == rhs.id && lhs.alarmState == rhs.alarmState
    }
    
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let alarmState: Alarm.State
    public let totalSeconds: Int
    public let metadata: RecipeTimerMetadata
    public var presentation: RecipeTimerPresentation
    
    
    public struct CodableSnapshot: Codable {
        public let id: UUID
        public let title: String
        public let createdAt: Date
        public let alarmState: Alarm.State
        public let totalSeconds: Int
        public let presentation: RecipeTimerPresentation
        public let metadata: RecipeTimerMetadata
    }
    
    public var snapshot: CodableSnapshot {
        .init(id: id, title: title, createdAt: createdAt, alarmState: alarmState, totalSeconds: totalSeconds, presentation: presentation, metadata: metadata)
    }
    
    public init(from state: CodableSnapshot) {
        self.id = state.id
        self.title = state.title
        self.createdAt = state.createdAt
        self.alarmState = state.alarmState
        self.totalSeconds = state.totalSeconds
        self.presentation = state.presentation
        self.metadata = state.metadata
    }
    
    
    public init(id: UUID, title: String, createdAt: Date, alarmState: Alarm.State, totalSeconds: Int, metadata: RecipeTimerMetadata, presentation: RecipeTimerPresentation) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.alarmState = alarmState
        self.totalSeconds = totalSeconds
        self.metadata = metadata
        self.presentation = presentation
    }
}

@MainActor
@Observable
public final class RecipeTimerStore {
    
    public static let shared = RecipeTimerStore()
    
    private let manager = AlarmManager.shared
    private let group = UserDefaults(suiteName: "group.sporkcast") ?? UserDefaults.standard
    private let persistedKey = "running-alarms.v1"
    
    public var timers: [RecipeTimerRowModel] = []
    private var persisted: [UUID: RecipeTimerRowModel.CodableSnapshot] = [:]
    
    public init() {
        loadPersisted()
        Task { await observeAlarmUpdates() }
    }
    
    @MainActor
    public func scheduleRecipeStepTimer(for recipeId: UUID, recipeStepId: UUID, timerIndex: Int, seconds: Int, title: String, description: String?, tint: Color = Color.orange) async throws -> UUID {
        try await ensureAuth()
        
        let pauseButton = AlarmButton(text: "Pause", textColor: tint, systemImageName: "pause.fill.circle")
        let resumeButton = AlarmButton(text: "Resume", textColor: tint, systemImageName: "play.fill.circle")
        let stopButton = AlarmButton(text: "Stop", textColor: tint, systemImageName: "xmark")
        
        let alert = AlarmPresentation.Alert(title: "\(title)", stopButton: stopButton)
        let countdown = AlarmPresentation.Countdown(title: "\(title)", pauseButton: pauseButton)
        let paused = AlarmPresentation.Paused(title: "Paused", resumeButton: resumeButton)
        
        let attributes = AlarmAttributes(presentation: .init(alert: alert, countdown: countdown, paused: paused), metadata: RecipeTimerMetadata(title: title, createdAt: .now, colorHex: tint.toHex() ?? "#FFFFFF", recipeStepId: recipeStepId, stepTimerIndex: timerIndex, recipeId: recipeId, description: description), tintColor: tint)
        
        let stopIntent = StopTimerIntent()
        let pauseIntent = PauseTimerIntent()
//        let resumeIntent = ResumeTimerIntent()
        
        let config = AlarmManager.AlarmConfiguration<RecipeTimerMetadata>.timer(duration: .init(seconds), attributes: attributes, stopIntent: stopIntent, secondaryIntent: pauseIntent, sound: .default)
        
        let id = UUID()
        let alarm = try await manager.schedule(id: id, configuration: config)
        
        upsertFromAlarm(alarm: alarm, metadata: attributes.metadata, manualTransition: .countdown(total: .init(seconds), previouslyElapsed: 0, startDate: .now))
        
        persist()
        return id
    }
    
    public func pause(_ id: UUID) async {
        do {
            try manager.pause(id: id)
            applyManualPause(id: id)
            persist()
        } catch {
            print("pauseError:", error)
        }
    }
    
    public func resume(_ id: UUID) async {
        do {
            try manager.resume(id: id)
            applyManualResume(id: id)
            persist()
        } catch { print("resume error:", error) }
    }
    
    public func cancel(_ id: UUID) async {
        do {
            try manager.cancel(id: id)
        } catch { print("cancel error:", error) }
        timers.removeAll { $0.id == id }
        persisted[id] = nil
        persist()
    }
    
    private func observeAlarmUpdates() async {
        for await alarms in manager.alarmUpdates {
            for alarm in alarms {
                let meta = persisted[alarm.id]?.metadata ?? .init(title: "Timer", createdAt: .now, colorHex: "#FFFFFF", recipeStepId: UUID(), stepTimerIndex: 0, recipeId: UUID(), description: nil)
                upsertFromAlarm(alarm: alarm, metadata: meta, manualTransition: nil)
            }
            
            let activeIds = Set(alarms.map(\.id))
            timers.removeAll { !activeIds.contains($0.id) }
            timers.sort { $0.createdAt > $1.createdAt }
            persist()
        }
    }
    
    private func upsertFromAlarm(alarm: Alarm, metadata: RecipeTimerMetadata?, manualTransition: RecipeTimerPresentation.Mode?) {
        let meta = metadata ?? .init(title: "Timer", createdAt: .now, colorHex: "#FFFFFF", recipeStepId: UUID(), stepTimerIndex: 0, recipeId: UUID(), description: nil)
        
        let existing = timers.first(where: { $0.id == alarm.id })
        let newMode: RecipeTimerPresentation.Mode = {
            if let manual = manualTransition { return manual }
            
            switch alarm.state {
            case .scheduled:
                if case let .fixed(date) = alarm.schedule {
                    return .scheduled(fireDate: date)
                }
                
                return existing?.presentation.mode ?? .alerting
            case .countdown:
                let total = TimeInterval(alarm.countdownDuration?.preAlert ?? 0)
                let prev = existing?.presentation.elapsedOrZero ?? 0
                return .countdown(total: total, previouslyElapsed: prev, startDate: .now)
            case .paused:
                let total = TimeInterval(alarm.countdownDuration?.preAlert ?? 0)
                let prev = existing?.presentation.elapsedOrZero ?? 0
                return .paused(total: total, previouslyElapsed: prev)
            case .alerting:
                return .alerting
            @unknown default:
                return existing?.presentation.mode ?? .alerting
            }
        }()
        
        let row = RecipeTimerRowModel(id: alarm.id, title: meta.title, createdAt: meta.createdAt, alarmState: alarm.state, totalSeconds: Int(alarm.countdownDuration?.preAlert ?? 0), metadata: meta, presentation: .init(mode: newMode))
        
        if let idx = timers.firstIndex(where: { $0.id == alarm.id }) {
            timers[idx] = row
        } else {
            timers.insert(row, at: 0)
        }
        
        persisted[alarm.id] = row.snapshot
    }
    
    private func applyManualPause(id: UUID) {
        guard let idx = timers.firstIndex(where: { $0.id == id }) else { return }
        let item = timers[idx]
        switch item.presentation.mode {
        case .countdown(let total, let prev, let start):
            let elapsed = prev + Date().timeIntervalSince(start)
            timers[idx].presentation.mode = .paused(total: total, previouslyElapsed: elapsed)
        default: break
        }
        persisted[id] = timers[idx].snapshot
    }
    
    private func applyManualResume(id: UUID) {
        guard let idx = timers.firstIndex(where: { $0.id == id }) else { return }
        let item = timers[idx]
        switch item.presentation.mode {
        case .paused(let total, let prev):
            timers[idx].presentation.mode = .countdown(total: total, previouslyElapsed: prev, startDate: .now)
        default: break
        }
        persisted[id] = timers[idx].snapshot
    }
    
    private func ensureAuth() async throws {
        switch manager.authorizationState {
        case .authorized: return
        case .notDetermined:
            let state = try await manager.requestAuthorization()
            guard state == .authorized else { throw AuthorizationError.denied }
        case .denied:
            throw AuthorizationError.denied
        @unknown default:
            throw AuthorizationError.denied
        }
    }
    
    public enum AuthorizationError: Error { case denied }

    
    private func loadPersisted() {
        guard let data = group.data(forKey: persistedKey),
              let decoded = try? JSONDecoder().decode([UUID: RecipeTimerRowModel.CodableSnapshot].self, from: data) else {
            return
        }
        
        persisted = decoded
        timers = decoded.values
//            .filter { $0.alarmState != .alerting }
            .map { RecipeTimerRowModel(from: $0) }
            .sorted { $0.createdAt > $1.createdAt }

        persist()
    }
    
    private func persist() {
        let data = try? JSONEncoder().encode(persisted)
        group.set(data, forKey: persistedKey)
    }
}


extension RecipeTimerPresentation {

    var elapsedOrZero: TimeInterval {
        switch mode {
        case .countdown(_, let previouslyElapsed, let startDate):
            return previouslyElapsed + Date().timeIntervalSince(startDate)
        case .paused(_, let previouslyElapsed):
            return previouslyElapsed
        case .alerting, .scheduled:
            return 0
        }
    }
}

public struct PauseTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pause Timer"
    @Parameter(title: "Alarm ID") public var alarmID: String
    
    public init() {}
    public init(alarmID: UUID) { self.alarmID = alarmID.uuidString }
    
    public func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await RecipeTimerStore.shared.pause(id)
        return .result()
    }
}

public struct ResumeTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Resume Timer"
    @Parameter(title: "Alarm ID") var alarmID: String
    
    public init() {}
    public init(alarmID: UUID) { self.alarmID = alarmID.uuidString }
    
    public func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await RecipeTimerStore.shared.resume(id)
        return .result()
    }
}

public struct StopTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Stop Timer"
    @Parameter(title: "Alarm ID") var alarmID: String
    
    public init() {}
    public init(alarmID: UUID) { self.alarmID = alarmID.uuidString }
    
    public func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await RecipeTimerStore.shared.cancel(id)
        return .result()
    }
}

