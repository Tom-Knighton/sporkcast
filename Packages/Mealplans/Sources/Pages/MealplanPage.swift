//
//  MealplanPage.swift
//  Mealplans
//
//  Created by Tom Knighton on 15/11/2025.
//

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
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        do {
                            let recipeId = try await db.read { db in
                                try DBRecipe
                                    .select(\.id)
                                    .fetchOne(db)
                            }
                                                        
                            let newEntry = DBMealplanEntry(id: UUID(), date: Date(), index: 0, noteText: nil, recipeId: recipeId)
                            try await db.write { db in
                                try DBMealplanEntry
                                    .insert { newEntry }
                                    .execute(db)
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }

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
