//
//  MealplanWidgetSnapshotStore.swift
//  Environment
//
//  Created by Tom Knighton on 25/05/2026.
//

import Foundation
import Models

public struct MealplanWidgetSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var hasProAccess: Bool
    public var days: [MealplanWidgetDay]

    public init(generatedAt: Date, hasProAccess: Bool, days: [MealplanWidgetDay]) {
        self.generatedAt = generatedAt
        self.hasProAccess = hasProAccess
        self.days = days
    }
}

public struct MealplanWidgetDay: Codable, Identifiable, Sendable, Equatable {
    public var id: String { dateKey }

    public let date: Date
    public let dateKey: String
    public let entries: [MealplanWidgetMeal]

    public init(date: Date, dateKey: String, entries: [MealplanWidgetMeal]) {
        self.date = date
        self.dateKey = dateKey
        self.entries = entries
    }
}

public struct MealplanWidgetMeal: Codable, Identifiable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case recipe
        case note
    }

    public let id: UUID
    public let kind: Kind
    public let title: String
    public let detail: String?
    public let accentHex: String?

    public init(id: UUID, kind: Kind, title: String, detail: String?, accentHex: String?) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.accentHex = accentHex
    }
}

public enum MealplanWidgetSnapshotStore {
    public static let widgetKind = "MealplanWidget"

    private static let snapshotKey = "widgets.mealplan.snapshot.v1"
    private static let proAccessKey = "widgets.mealplan.proAccess.v1"
    private static let selectedDayOffsetKey = "widgets.mealplan.selectedDayOffset.v1"
    private static let dayCount = 14

    public static var selectedDayOffset: Int {
        get {
            UserDefaults.appGroup.object(forKey: selectedDayOffsetKey) as? Int ?? 0
        }
        set {
            UserDefaults.appGroup.set(clampedDayOffset(newValue), forKey: selectedDayOffsetKey)
        }
    }

    public static func moveSelectedDay(by delta: Int) {
        selectedDayOffset = selectedDayOffset + delta
    }

    public static func setHasProAccess(_ hasProAccess: Bool) {
        let defaults = UserDefaults.appGroup
        defaults.set(hasProAccess, forKey: proAccessKey)
        defaults.synchronize()

        var snapshot = load()
        snapshot.hasProAccess = hasProAccess
        write(snapshot)
    }

    public static func load(now: Date = .now, calendar: Calendar = .current) -> MealplanWidgetSnapshot {
        guard let data = UserDefaults.appGroup.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(MealplanWidgetSnapshot.self, from: data) else {
            return emptySnapshot(now: now, calendar: calendar)
        }

        return snapshot
    }

    public static func write(entries: [MealplanEntry], now: Date = .now, calendar: Calendar = .current) {
        let hasProAccess = UserDefaults.appGroup.object(forKey: proAccessKey) as? Bool ?? false
        let startDate = calendar.startOfDay(for: now)
        let days = (0..<dayCount).compactMap { offset -> MealplanWidgetDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let dayEntries = entries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .sorted { lhs, rhs in
                    if lhs.index == rhs.index {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.index < rhs.index
                }
                .map(MealplanWidgetMeal.init(entry:))

            return MealplanWidgetDay(
                date: date,
                dateKey: dayKey(for: date, calendar: calendar),
                entries: dayEntries
            )
        }

        write(MealplanWidgetSnapshot(generatedAt: now, hasProAccess: hasProAccess, days: days))
    }

    public static func dateRange(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let startDate = calendar.startOfDay(for: now)
        let endDate = calendar.date(byAdding: .day, value: dayCount - 1, to: startDate) ?? startDate
        return startDate...endDate
    }

    private static func write(_ snapshot: MealplanWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.appGroup.set(data, forKey: snapshotKey)
    }

    private static func emptySnapshot(now: Date, calendar: Calendar) -> MealplanWidgetSnapshot {
        let hasProAccess = UserDefaults.appGroup.object(forKey: proAccessKey) as? Bool ?? false
        let startDate = calendar.startOfDay(for: now)
        let days = (0..<dayCount).compactMap { offset -> MealplanWidgetDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return MealplanWidgetDay(
                date: date,
                dateKey: dayKey(for: date, calendar: calendar),
                entries: []
            )
        }

        return MealplanWidgetSnapshot(generatedAt: now, hasProAccess: hasProAccess, days: days)
    }

    private static func clampedDayOffset(_ offset: Int) -> Int {
        min(max(offset, 0), dayCount - 1)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private extension MealplanWidgetMeal {
    init(entry: MealplanEntry) {
        if let recipe = entry.recipe {
            self.init(
                id: entry.id,
                kind: .recipe,
                title: recipe.title,
                detail: recipe.timing.totalTime.map(Self.durationText(for:)),
                accentHex: recipe.dominantColorHex
            )
        } else {
            self.init(
                id: entry.id,
                kind: .note,
                title: entry.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Meal note",
                detail: "Note",
                accentHex: nil
            )
        }
    }

    private static func durationText(for minutes: Double) -> String {
        let rounded = Int(minutes.rounded())
        guard rounded > 0 else { return "Quick meal" }

        if rounded >= 60 {
            let hours = rounded / 60
            let mins = rounded % 60
            return mins == 0 ? "\(hours) hr" : "\(hours) hr \(mins) min"
        }

        return "\(rounded) min"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
