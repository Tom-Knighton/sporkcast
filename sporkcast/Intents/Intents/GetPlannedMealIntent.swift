//
//  AskMealplanIntent.swift
//  sporkcast
//
//  Created by Tom Knighton on 16/06/2026.
//

import Foundation
import AppIntents
import Environment
import SwiftUI

@available(anyAppleOS 27.0, *)
public struct GetPlannedMealIntent: AppIntent {
    
    @MainActor
    private var repository = MealplanRepository()
    
    public static let title: LocalizedStringResource = "Get Planned Meals"
    public static let description = IntentDescription("Shows what is planned for today, this week, or next week")
    
    @Parameter(title: "When")
    public var period: MealPlanPeriod
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Show mealplan for \(\.$period)")
    }
    
    public init() {
        self.period = .thisWeek
    }
    
    public init(range: MealPlanPeriod) {
        self.period = range
    }
    
    public func perform() async throws -> some IntentResult & ReturnsValue<[PlannedMealEntity]> & ProvidesDialog & ShowsSnippetView  {
        
        let interval = period.dateInterval()
        
        let entries = try await repository.entries(startDate: interval.start, endDate: interval.end)
            .compactMap { PlannedMealEntity(mealplanEntry: $0) }
        
        let dialog = MealplanDialogBuilder.dialog(for: entries, range: period)
        
        return .result(value: entries, dialog: "\(dialog)") {
            MealplanSnippetView(title: period.displayName, plannedMeals: entries)
        }
    }
}
