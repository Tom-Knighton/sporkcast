//
//  AppIntent.swift
//  countdownextension
//
//  Created by Tom Knighton on 27/09/2025.
//

import WidgetKit
import AppIntents
import Environment

enum MealplanWidgetPageDirection: String, AppEnum {
    case previous
    case next

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Mealplan Page Direction"
    }

    static var caseDisplayRepresentations: [MealplanWidgetPageDirection: DisplayRepresentation] {
        [
            .previous: "Previous day",
            .next: "Next day"
        ]
    }
}

struct MealplanWidgetPageIntent: AppIntent {
    static var title: LocalizedStringResource { "Change Mealplan Day" }
    static var description: IntentDescription { "Shows another upcoming mealplan day in the widget." }

    @Parameter(title: "Direction")
    var direction: MealplanWidgetPageDirection

    init() {}

    init(direction: MealplanWidgetPageDirection) {
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        MealplanWidgetSnapshotStore.moveSelectedDay(by: direction == .next ? 1 : -1)
        WidgetCenter.shared.reloadTimelines(ofKind: MealplanWidgetSnapshotStore.widgetKind)
        return .result()
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
