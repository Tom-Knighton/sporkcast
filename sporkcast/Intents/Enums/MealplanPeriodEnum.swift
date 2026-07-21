//
//  MealplanPeriodEnum.swift
//  sporkcast
//
//  Created by Tom Knighton on 16/06/2026.
//

import Foundation
import AppIntents

public enum MealPlanPeriod: String, AppEnum, Sendable {
    case yesterday
    case today
    case tomorrow
    case thisWeek
    case nextWeek
    
    static public var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Meal Plan Range")
    
    public static var caseDisplayRepresentations: [MealPlanPeriod : DisplayRepresentation] = [
        .yesterday: "Yesterday",
        .today: "Today",
        .tomorrow: "Tomorrow",
        .thisWeek: "This week",
        .nextWeek: "Next week",
    ]
    
    public var displayName: String {
        switch self {
        case .yesterday:
            "yesterday"
        case .today:
            "today"
        case .tomorrow:
            "tomorrow"
        case .thisWeek:
            "this week"
        case .nextWeek:
            "next week"
        }
    }
    
    public func dateInterval(now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        var calendar = calendar
        calendar.firstWeekday = 2
        
        switch self {
        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -1, to: todayStart)!
            let end = todayStart
            return DateInterval(start: start, end: end)
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .tomorrow:
            let todayStart = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .thisWeek:
            let start = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            )!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return DateInterval(start: start, end: end)
        case .nextWeek:
            let thisWeekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            )!
            let start = calendar.date(byAdding: .day, value: 7, to: thisWeekStart)!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return DateInterval(start: start, end: end)
        }
    }
}
