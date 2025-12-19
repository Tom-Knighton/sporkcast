//
//  Date+lastMonday.swift
//  Design
//
//  Created by Tom Knighton on 17/11/2025.
//

import Foundation

public extension Date {
    
    /// Returns the most recent Monday strictly before `self` (never returns today).
    func lastMonday(calendar: Calendar = .current) -> Date {
        let startOfSelf = calendar.startOfDay(for: self)
        let monday = DateComponents(weekday: 2)
        return calendar.nextDate(
            after: startOfSelf,
            matching: monday,
            matchingPolicy: .nextTime,
            direction: .backward
        )!
    }
}
