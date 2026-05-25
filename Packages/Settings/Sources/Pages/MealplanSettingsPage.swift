//
//  MealplanSettingsPage.swift
//  Settings
//

import Design
import Environment
import SwiftUI

struct MealplanSettingsPage: View {
    @Environment(\.appSettings) private var store

    private let weekStartOptions: [(weekday: Int, title: String)] = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]

    var body: some View {
        List {
            Section {
                Toggle("Show Mealplan Tab", isOn: store.binding(\.showMealplanPage))
            }

            Section("Display") {
                Toggle("Grey Out Past Days", isOn: store.binding(\.greyOutPastMealplanDays))

                Picker("Week Starts On", selection: store.binding(\.mealplanWeekStartWeekday)) {
                    ForEach(weekStartOptions, id: \.weekday) { option in
                        Text(option.title).tag(option.weekday)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mealplan")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
    }
}
