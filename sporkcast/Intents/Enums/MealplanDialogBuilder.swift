//
//  MealplanDialogBuilder.swift
//  sporkcast
//
//  Created by Tom Knighton on 18/06/2026.
//

@available(anyAppleOS 27.0, *)
public enum MealplanDialogBuilder {
    nonisolated static func dialog(for meals: [PlannedMealEntity], range: MealPlanPeriod) -> String {
        guard !meals.isEmpty else {
            return "Nothing is planned for \(range.displayName)"
        }
        
        switch range {
        case .today, .yesterday, .tomorrow:
            return meals
                .map { "\($0.recipeName)"}
                .joined(separator: ", ")
            
        case .thisWeek, .nextWeek:
            let count = meals.count
            let firstFew = meals
                .prefix(3)
                .map { "\($0.recipeName)" }
                .joined(separator: ", ")
            
            if count <= 3 {
                return "\(range.displayName), you have \(firstFew) planned."
            }
            
            return "\(range.displayName), you have \(count) meals planned, starting with \(firstFew)."
        }
    }
}
