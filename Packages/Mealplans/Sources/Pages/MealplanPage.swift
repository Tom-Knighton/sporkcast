//
//  MealplanPage.swift
//  Mealplans
//
//  Created by Tom Knighton on 15/11/2025.
//

import Environment
import SwiftUI
import Design
import Dependencies
import Persistence
import SQLiteData
import Models

public struct MealplanPage: View {
    
    public init() {}
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @State private var startDate = Date().lastMonday()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
    @State private var now = Date()
    @State private var scrollPosition: ScrollPosition = .init(id: 1)
    @State private var isDraggingEntry: Bool = false
    
    @FetchAll var mealplanEntries: [FullDBMealplanEntry]
    @Dependency(\.defaultDatabase) private var db
    
    private var days: [Date] {
        var result: [Date] = []
        var date = startDate
        while date <= endDate {
            result.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return result
    }
    
    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack {
                        ForEach(days, id: \.self) { day in
                            let mealplanEntries = self.mealplanEntries
                                .filter { calendar.isDate($0.mealplanEntry.date, inSameDayAs: day)}
                                .sorted(by: { $0.mealplanEntry.index < $1.mealplanEntry.index })
                            MealplanRowView(for: day, with: mealplanEntries.compactMap { $0.toDomainModel() }, currentDate: now, isDraggingEntry: $isDraggingEntry)
                                .id(day.formatted(date: .numeric, time: .omitted))
                                .onAppear {
                                    extendDaysIfNeeded(currentDay: day)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        self.scrollPosition = .init(id: now.formatted(date: .numeric, time: .omitted), anchor: .top)
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollPosition($scrollPosition)
                .environment(\.isMealplanDragging, isDraggingEntry)
                
            }
        }
        .navigationTitle("Mealplan")
        .task(id: [startDate, endDate]) {
            await updateQuery()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
                let newStart = Date().lastMonday()
                if newStart != startDate {
                    startDate = newStart
                    endDate = calendar.date(byAdding: .day, value: 7, to: .now)!
                }
                Task {
                    await updateQuery()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            now = Date()
            let newStart = Date().lastMonday()
            if newStart != startDate {
                startDate = newStart
                endDate = calendar.date(byAdding: .day, value: 7, to: .now)!
            }
            Task {
                await updateQuery()
            }
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
            try await $mealplanEntries.load(
                DBMealplanEntry.full(startDate: startDate, endDate: endDate)
            )
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
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
                        recipeId: recipeId
                    )
                }
                .execute(db)
            }
        } catch {
            print("Preview DB setup failed: \(error)")
        }
    })
    
    NavigationStack {
        MealplanPage()
    }
    .environment(AppRouter(initialTab: .mealplan))
    
}
