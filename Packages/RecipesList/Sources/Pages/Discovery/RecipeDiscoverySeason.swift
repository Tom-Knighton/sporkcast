//
//  RecipeDiscoverySeason.swift
//  RecipesList
//

import Foundation

enum RecipeDiscoverySeason {
    static func current(calendar: Calendar = .current, date: Date = .now) -> String {
        switch calendar.component(.month, from: date) {
        case 3...5:
            return "spring"
        case 6...8:
            return "summer"
        case 9...11:
            return "autumn"
        default:
            return "winter"
        }
    }
}
