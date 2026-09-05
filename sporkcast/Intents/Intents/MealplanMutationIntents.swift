//
//  MealplanMutationIntents.swift
//  sporkcast
//

import AppIntents
import Environment
import Foundation
import Models

@available(anyAppleOS 27.0, *)
public struct AddRecipeToMealplanIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Recipe to Mealplan"
    public static let description = IntentDescription("Adds a recipe to the Sporkcast mealplan.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Recipe",
        requestValueDialog: "Which recipe should I add?",
        requestDisambiguationDialog: "Which recipe did you mean?",
        query: RecipeEntryEntityQuery()
    )
    public var recipe: RecipeEntity

    @Parameter(title: "Date", requestValueDialog: "Which day should I plan it for?")
    public var date: Date

    @MainActor private var repository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$recipe) to mealplan on \(\.$date)")
    }

    public init() {
        self.date = .now
    }

    public init(recipe: RecipeEntity, date: Date = .now) {
        self.recipe = recipe
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let plannedDate = Self.startOfDay(for: date)
        let nextIndex = try await Self.nextMealplanIndex(on: plannedDate, repository: repository)
        try await repository.addRecipeEntry(
            date: plannedDate,
            index: nextIndex,
            recipeId: recipe.id,
            homeId: HouseholdService.shared.home?.id
        )

        return .result(dialog: "Added \(recipe.title) to the mealplan for \(plannedDate.formatted(date: .abbreviated, time: .omitted)).")
    }
}

@available(anyAppleOS 27.0, *)
public struct AddRandomMealToMealplanIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Random Meal to Mealplan"
    public static let description = IntentDescription("Adds a random saved recipe to the Sporkcast mealplan.")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Date", requestValueDialog: "Which day should I plan it for?")
    public var date: Date

    @MainActor private var repository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Add a random meal to mealplan on \(\.$date)")
    }

    public init() {
        self.date = .now
    }

    public init(date: Date = .now) {
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let plannedDate = AddRecipeToMealplanIntent.startOfDay(for: date)
        let nextIndex = try await AddRecipeToMealplanIntent.nextMealplanIndex(on: plannedDate, repository: repository)
        try await repository.insertRandomMeal(
            date: plannedDate,
            index: nextIndex,
            homeId: HouseholdService.shared.home?.id
        )

        return .result(dialog: "Added a random meal to the mealplan for \(plannedDate.formatted(date: .abbreviated, time: .omitted)).")
    }
}

@available(anyAppleOS 27.0, *)
public struct RemoveMealFromMealplanIntent: AppIntent {
    public static let title: LocalizedStringResource = "Remove Meal from Mealplan"
    public static let description = IntentDescription("Removes a planned meal from the Sporkcast mealplan.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Meal",
        requestValueDialog: "Which planned meal should I remove?",
        requestDisambiguationDialog: "Which planned meal did you mean?",
        query: PlannedMealQuery()
    )
    public var meal: PlannedMealEntity

    @MainActor private var repository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$meal) from mealplan")
    }

    public init() {}

    public init(meal: PlannedMealEntity) {
        self.meal = meal
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await repository.deleteEntry(id: meal.id)
        return .result(dialog: "Removed \(meal.title) from the mealplan.")
    }
}

@available(anyAppleOS 27.0, *)
public struct MoveMealInMealplanIntent: AppIntent {
    public static let title: LocalizedStringResource = "Move Meal in Mealplan"
    public static let description = IntentDescription("Moves a planned meal to another date in the Sporkcast mealplan.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Meal",
        requestValueDialog: "Which planned meal should I move?",
        requestDisambiguationDialog: "Which planned meal did you mean?",
        query: PlannedMealQuery()
    )
    public var meal: PlannedMealEntity

    @Parameter(title: "Date", requestValueDialog: "Which day should I move it to?")
    public var date: Date

    @MainActor private var repository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$meal) to \(\.$date)")
    }

    public init() {
        self.date = .now
    }

    public init(meal: PlannedMealEntity, date: Date = .now) {
        self.meal = meal
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let plannedDate = AddRecipeToMealplanIntent.startOfDay(for: date)
        let nextIndex = try await AddRecipeToMealplanIntent.nextMealplanIndex(on: plannedDate, repository: repository)
        let existingEntries = try await entries(on: plannedDate)
        try await repository.moveEntry(entryId: meal.id, to: plannedDate, index: nextIndex, existingEntries: existingEntries)

        return .result(dialog: "Moved \(meal.title) to \(plannedDate.formatted(date: .abbreviated, time: .omitted)).")
    }

    @MainActor
    private func entries(on date: Date) async throws -> [MealplanEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return try await repository.entries(startDate: start, endDate: end)
    }
}

@available(anyAppleOS 27.0, *)
public struct AddMealplanNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Mealplan Note"
    public static let description = IntentDescription("Adds a note to the Sporkcast mealplan.")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Note", requestValueDialog: "What note should I add?")
    public var note: String

    @Parameter(title: "Date", requestValueDialog: "Which day should I add it to?")
    public var date: Date

    @MainActor private var repository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Add note \(\.$note) to mealplan on \(\.$date)")
    }

    public init() {
        self.note = ""
        self.date = .now
    }

    public init(note: String, date: Date = .now) {
        self.note = note
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            return .result(dialog: "I couldn't tell what note to add.")
        }

        let plannedDate = AddRecipeToMealplanIntent.startOfDay(for: date)
        let nextIndex = try await AddRecipeToMealplanIntent.nextMealplanIndex(on: plannedDate, repository: repository)
        try await repository.addNoteEntry(
            date: plannedDate,
            index: nextIndex,
            text: trimmedNote,
            homeId: HouseholdService.shared.home?.id
        )

        return .result(dialog: "Added a note to the mealplan for \(plannedDate.formatted(date: .abbreviated, time: .omitted)).")
    }
}

@available(anyAppleOS 27.0, *)
public struct UpdateMealplanNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Update Mealplan Note"
    public static let description = IntentDescription("Updates a mealplan note in Sporkcast.")
    public static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Planned Item",
        requestValueDialog: "Which mealplan note should I update?",
        requestDisambiguationDialog: "Which planned item did you mean?",
        query: PlannedMealQuery()
    )
    public var meal: PlannedMealEntity

    @Parameter(title: "Note", requestValueDialog: "What should the note say?")
    public var note: String

    @MainActor private var repository = MealplanRepository()

    public static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$meal) note to \(\.$note)")
    }

    public init() {
        self.note = ""
    }

    public init(meal: PlannedMealEntity, note: String) {
        self.meal = meal
        self.note = note
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            return .result(dialog: "I couldn't tell what the note should say.")
        }

        try await repository.updateNote(id: meal.id, text: trimmedNote)
        return .result(dialog: "Updated \(meal.title).")
    }
}

@available(anyAppleOS 27.0, *)
extension AddRecipeToMealplanIntent {
    static func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    @MainActor
    static func nextMealplanIndex(on date: Date, repository: MealplanRepository) async throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return try await repository.entries(startDate: start, endDate: end).count
    }
}
