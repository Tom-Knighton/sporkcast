//
//  MealplanPage.swift
//  Mealplans
//
//  Created by Tom Knighton on 15/11/2025.
//

import Environment
import SwiftUI
import Design
import Persistence
import Models

public struct MealplanPage: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.homeServices) private var homes
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @Environment(\.appSettings) private var appSettings
    @Environment(\.flagKit) private var flagKit
    @Environment(\.proAccess) private var proAccess
    
    @State private var startDate = MealplanPage.currentWeekRange(containing: .now, firstWeekday: 2).lowerBound
    @State private var endDate = MealplanPage.currentWeekRange(containing: .now, firstWeekday: 2).upperBound
    @State private var now = Date()
    @State private var scrollPosition = ScrollPosition(id: Calendar.current.startOfDay(for: Date.now), anchor: .top)
    @State private var hasScrolledToToday = false
    @State private var hasRoomForPicker = false
    @State private var selectedDay = Calendar.current.startOfDay(for: Date.now)
    @State private var showingRecipePicker = false
    @State private var isAddingEntry = false
    @State private var additionConfirmation: String?
    @State private var additionError: String?
    @State private var isDraggingEntry: Bool = false
    @State private var repository = MealplanRepository()
    @State private var mealplanWeather = MealplanWeatherService.shared
    @State private var showingShoppingListFlow = false
    
    public init() {}
    
    private var days: [Date] {
        var result: [Date] = []
        var date = startDate
        while date <= endDate {
            result.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return result
    }

    private var shouldShowWeather: Bool {
        appSettings.settings.showMealplanWeather
            && flagKit.isEnabled(.mealplanWeatherPro, default: proAccess.hasProAccess)
    }

    private var weekStartWeekday: Int {
        min(max(appSettings.settings.mealplanWeekStartWeekday, 1), 7)
    }
    
    public var body: some View {
        MealplanPickerLayout(showsPicker: showsInlinePicker) {
            MealplanDaysView(
                days: days,
                entries: repository.entries,
                currentDate: now,
                selectedDay: showsInlinePicker ? selectedDay : nil,
                weatherService: shouldShowWeather ? mealplanWeather : nil,
                shouldGreyOutPastDays: appSettings.settings.greyOutPastMealplanDays,
                isDraggingEntry: $isDraggingEntry,
                scrollPosition: $scrollPosition,
                hasScrolledToToday: $hasScrolledToToday,
                onAddMeal: selectDayForAdding,
                onDayAppeared: extendDaysIfNeeded
            )

        } picker: {
            MealplanRecipePickerView(
                day: selectedDay,
                isAddingEntry: isAddingEntry,
                confirmation: additionConfirmation,
                onRecipeSelected: addRecipe,
                onQuickSelect: quickSelectMeal,
                onRandomRecipeSelected: addRandomRecipe,
                onNoteSaved: addNote
            )
        }
        .background(Color.layer1.ignoresSafeArea())
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.size.width >= 700 && geometry.size.width > geometry.size.height
        } action: { hasRoomForPicker = $0 }
        .onChange(of: showsInlinePicker) { _, isInline in
            if isInline { showingRecipePicker = false }
        }
        .onChange(of: now) { _, date in
            if selectedDay < calendar.startOfDay(for: date) {
                selectedDay = calendar.startOfDay(for: date)
                additionConfirmation = nil
            }
        }
        .environment(repository)
        .navigationTitle("Mealplan")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add To Shopping", systemImage: "cart.badge.plus") {
                    showingShoppingListFlow = true
                }
                .accessibilityLabel("Add mealplan ingredients to shopping list")
            }
        }
        .sheet(isPresented: $showingShoppingListFlow) {
            MealplanToShoppingListFlowView(
                initialStartDate: startDate,
                initialEndDate: endDate
            )
        }
        .sheet(isPresented: $showingRecipePicker) {
            MealplanRecipePickerView(
                day: selectedDay,
                isAddingEntry: isAddingEntry,
                confirmation: additionConfirmation,
                onRecipeSelected: addRecipe,
                onQuickSelect: quickSelectMeal,
                onRandomRecipeSelected: addRandomRecipe,
                onNoteSaved: addNote,
                onClose: { showingRecipePicker = false }
            )
        }
        .alert("Couldn't Add Meal", isPresented: Binding(
            get: { additionError != nil },
            set: { if !$0 { additionError = nil } }
        )) {
            Button("OK", role: .cancel) { additionError = nil }
        } message: {
            Text(additionError ?? "Please try again.")
        }
        .task(id: [startDate, endDate]) {
            await updateQuery()
            await updateWeatherIfNeeded()
        }
        .task(id: weekStartWeekday) {
            syncVisibleWeekToSettings()
        }
        .task(id: shouldShowWeather) {
            await updateWeatherIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
                let currentWeek = Self.currentWeekRange(containing: now, calendar: calendar, firstWeekday: weekStartWeekday)
                if currentWeek.lowerBound != startDate {
                    startDate = currentWeek.lowerBound
                    endDate = currentWeek.upperBound
                }
                Task {
                    await updateQuery()
                    await updateWeatherIfNeeded()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            now = Date()
            let currentWeek = Self.currentWeekRange(containing: now, calendar: calendar, firstWeekday: weekStartWeekday)
            if currentWeek.lowerBound != startDate {
                startDate = currentWeek.lowerBound
                endDate = currentWeek.upperBound
            }
            Task {
                await updateQuery()
                await updateWeatherIfNeeded()
            }
        }
    }
    
    private var showsInlinePicker: Bool {
        horizontalSizeClass == .regular && hasRoomForPicker && !dynamicTypeSize.isAccessibilitySize
    }

    private func selectDayForAdding(_ day: Date) {
        selectedDay = calendar.startOfDay(for: day)
        additionConfirmation = nil
        if !showsInlinePicker { showingRecipePicker = true }
    }

    private func addRecipe(_ recipeId: UUID) async {
        do {
            try await addRandomRecipe(recipeId, to: selectedDay)
        } catch {
            additionError = error.localizedDescription
        }
    }

    private func addRandomRecipe(_ recipeId: UUID, to day: Date) async throws {
        try await performAddition(to: day) { index in
            try await repository.addRecipeEntry(
                date: day, index: index, recipeId: recipeId, homeId: homes.home?.id
            )
        }
    }

    private func quickSelectMeal(for day: Date) async {
        do {
            try await performAddition(to: day) { index in
                try await repository.insertRandomMeal(date: day, index: index, homeId: homes.home?.id)
            }
        } catch {
            additionError = error.localizedDescription
        }
    }

    private func addNote(_ text: String, to day: Date) async -> Bool {
        do {
            try await performAddition(to: day) { index in
                try await repository.addNoteEntry(date: day, index: index, text: text, homeId: homes.home?.id)
            }
            return true
        } catch {
            additionError = error.localizedDescription
            return false
        }
    }

    private func performAddition(to day: Date, operation: (Int) async throws -> Void) async throws {
        guard !isAddingEntry else { throw CancellationError() }
        isAddingEntry = true
        additionConfirmation = nil
        defer { isAddingEntry = false }

        let existingEntries = try await repository.entries(startDate: day, endDate: day)
        let nextIndex = (existingEntries.map(\.index).max() ?? -1) + 1
        try await operation(nextIndex)
        await updateQuery()
        if calendar.isDate(selectedDay, inSameDayAs: day) {
            let confirmation = "Added to \(day.formatted(date: .abbreviated, time: .omitted))"
            additionConfirmation = confirmation
            AccessibilityNotification.Announcement(confirmation).post()
            if !showsInlinePicker { showingRecipePicker = false }
        }
    }

    private func extendDaysIfNeeded(currentDay: Date) {
        let threshold = calendar.date(byAdding: .day, value: -7, to: endDate)!
        if currentDay >= threshold {
            if let newEnd = calendar.date(byAdding: .day, value: 60, to: endDate) {
                endDate = newEnd
            }
        }
    }
    
    private func updateQuery() async {
        do {
            try await repository.loadEntries(startDate: startDate, endDate: endDate)
        } catch {
            print(error.localizedDescription)
        }
    }

    private func updateWeatherIfNeeded() async {
        guard shouldShowWeather else { return }
        await mealplanWeather.loadDailyForecasts(startDate: startDate, endDate: endDate, calendar: calendar)
    }

    private func syncVisibleWeekToSettings() {
        let currentWeek = Self.currentWeekRange(containing: now, calendar: calendar, firstWeekday: weekStartWeekday)
        startDate = currentWeek.lowerBound
        endDate = currentWeek.upperBound
    }

    private static func currentWeekRange(containing date: Date, calendar: Calendar = .current, firstWeekday: Int) -> ClosedRange<Date> {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: startOfDay) ?? startOfDay
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return weekStart...weekEnd
    }
}

#Preview {
    @Previewable @Namespace var zm
    let today = Calendar(identifier: .iso8601).startOfDay(for: .now)
    let recipeId = UUID()
    
    let _ = PreviewSupport.preparePreviewDatabase(seed: { db in
        let now = Date()
        let recipe = DBRecipe(
            id: recipeId,
            title: "Preview Stir Fry",
            description: "Colourful veggies with noodles and peanut sauce.",
            author: "Preview Kitchen",
            sourceUrl: "https://example.com/stirfry",
            dominantColorHex: nil,
            minutesToPrepare: 10,
            minutesToCook: 15,
            totalMins: 25,
            serves: "2",
            overallRating: 4.7,
            totalRatings: 12,
            summarisedRating: "Quick comfort food",
            summarisedSuggestion: nil,
            dateAdded: now,
            dateModified: now,
            homeId: nil
        )

        do {
            try db.write { db in
                try DBRecipe.insert { recipe }.execute(db)
                try DBRecipeImage.insert { DBRecipeImage(recipeId: recipeId, imageSourceUrl: "https://www.allrecipes.com/thmb/xcOdImFBdut09lTsPnOxIjnv-2E=/0x512/filters:no_upscale():max_bytes(150000):strip_icc()/228823-quick-beef-stir-fry-DDMFS-4x3-1f79b031d3134f02ac27d79e967dfef5.jpg", imageData: nil) }.execute(db)
                try DBMealplanEntry.insert {
                    DBMealplanEntry(
                        id: UUID(),
                        date: today,
                        index: 0,
                        noteText: "Add extra chilli flakes",
                        recipeId: recipeId,
                        homeId: nil,
                    )
                }
                .execute(db)
            }
        } catch {
            print("Preview DB setup failed: \(error)")
        }
    })
    
    NavigationStack { MealplanPage() }
    .environment(AppRouter(initialTab: .mealplan))
    .environment(ZoomManager(zm))
    .environment(\.homeServices, MockHouseholdService())
}
