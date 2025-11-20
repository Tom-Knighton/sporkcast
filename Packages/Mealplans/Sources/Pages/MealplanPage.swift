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
    
    @Environment(\.calendar) private var calendar
    @State private var startDate = Date().lastMonday()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
    @State private var now = Date()
    @State private var scrollPosition: ScrollPosition = .init(id: 1)
    
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
                            let mealplanEntries = self.mealplanEntries.filter { calendar.isDate($0.mealplanEntry.date, inSameDayAs: day)}
                            MealplanRowView(for: day, with: mealplanEntries.compactMap { $0.toDomainModel() })
                                .id(day.formatted(date: .numeric, time: .omitted))
                                .onAppear {
                                    extendDaysIfNeeded(currentDay: day)
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        
                    }
                    .scrollTargetLayout()
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .safeAreaPadding()
                    .onAppear {
//                        reader.scrollTo(now.formatted(date: .numeric, time: .omitted), anchor: .top)
                        self.scrollPosition = .init(id: now.formatted(date: .numeric, time: .omitted), anchor: .top)
                    }
                }
                .scrollPosition($scrollPosition)
                
            }
        }
        .navigationTitle("Mealplan")
        .task(id: [startDate, endDate]) {
            await updateQuery()
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
