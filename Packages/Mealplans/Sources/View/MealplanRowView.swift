//
//  MealplanRowView.swift
//  Mealplans
//
//  Created by Tom Knighton on 17/11/2025.
//

import SwiftUI
import Design
import RecipesList
import SQLiteData
import Persistence
import Models
import Environment

public struct MealplanRowView: View {
    
    @Environment(AppRouter.self) private var router
    @Environment(\.calendar) private var calendar
    @Dependency(\.defaultDatabase) private var db
    public let day: Date
    public let entries: [MealplanEntry]
    public let currentDate: Date
    
    @State private var isRowTargeted = false
    @State private var hoveringIndex: Int? = nil
    @State private var draggingId: UUID? = nil
    @Binding private var isDragging: Bool
    @State private var showAddSheet: Bool = false
    
    private var isInPast: Bool {
        dayDifferenceFromNow(for: day) < 0
    }
    
    public init(for day: Date, with entries: [MealplanEntry], currentDate: Date, isDraggingEntry: Binding<Bool>) {
        self.day = day
        self.entries = entries
        self.currentDate = currentDate
        self._isDragging = isDraggingEntry
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text(dayTitle(for: day))
                        .bold()
                    Spacer()
                    
                    Button(action: { self.showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.white, .green)
                            .font(.title)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .contentShape(.rect)
                .dropDestination(for: MealplanEntry.self) { items, session in
                    Task {
                        self.draggingId = nil
                        self.isDragging = false
                        try await self.moveEntryToDay(entryId: items[0].id, date: day, index: 0)
                    }
                    return true
                } isTargeted: { val in
                    withAnimation {
                        self.isRowTargeted = val
                    }
                }
                
                DropGap(index: 0, hoveringIndex: $hoveringIndex, overrideIsTargeted: isRowTargeted) { insertIndex, droppedEntry in
                    self.draggingId = nil
                    self.isDragging = false
                    try await self.moveEntryToDay(entryId: droppedEntry.id, date: day, index: insertIndex)
                }
                
                ForEach(self.entries.enumerated(), id: \.element.id) { (idx, entry) in
                    if let recipe = entry.recipe, draggingId != entry.id {
                        RecipeCardView(recipe: recipe, enablePreview: false)
                            .padding(4)
                            .draggable(entry) {
                                RecipeCardView(recipe: recipe, enablePreview: false)
                                    .environment(router)
                                    .onAppear {
                                        self.draggingId = entry.id
                                    }
                            }
                            .transition(.opacity)
//                            .overlay {
//                                Text(String(describing: entry.mealplanEntry.index))
//                            }
//                        
                        DropGap(index: idx + 1, hoveringIndex: $hoveringIndex) { insertIndex, droppedEntry in
                            self.draggingId = nil
                            self.isDragging = false
                            try await self.moveEntryToDay(entryId: droppedEntry.id, date: day, index: insertIndex)
                        }
                    }
                    
                    // TODO: Notes
                    
                }
            }
            .overlay(isInPast ? .gray.opacity(0.25) : .clear)
            .fontDesign(.rounded)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .glassEffect(in: .rect(cornerRadius: 10))
            .clipShape(.rect(cornerRadius: 10))
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: .init(lineWidth: isInPast ? 2 : 4, dash: isInPast ? [5] : []))
                    .fill(isInPast ? .gray : calendar.isDateInToday(day) ? .blue : .clear)
            }
            .contentShape(.rect)
            .onChange(of: self.draggingId, { _, newValue in
                self.isDragging = newValue != nil
            })
            .sheet(isPresented: $showAddSheet) {
                selectorSheetView()
            }
            .id(currentDate)
        }
    }
    
    @ViewBuilder
    private func selectorSheetView() -> some View {
        NavigationStack {
            RecipePickerPage() { selectedId in
                self.showAddSheet.toggle()
                do {
                    let newEntry = DBMealplanEntry(id: UUID(), date: self.day, index: self.entries.count, noteText: nil, recipeId: selectedId)
                    try await db.write { db in
                        try DBMealplanEntry
                            .insert { newEntry }
                            .execute(db)
                    }
                } catch {
                    print(error)
                }
            }
            .toolbar {
                ToolbarItem {
                    Button(role: .close) { self.showAddSheet = false }
                }
            }
        }
    }
    
    private func dayTitle(for day: Date) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        }
        
        if calendar.isDateInTomorrow(day) {
            return "Tomorrow"
        }
        
        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }
        
        return day.formatted(date: .abbreviated, time: .omitted)
    }
    
    func dayDifferenceFromNow(for date: Date) -> Int
    {
        let startOfNow = calendar.startOfDay(for: currentDate)
        let startOfTimeStamp = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfNow, to: startOfTimeStamp)
        let day = components.day
        return day ?? 0
    }
    
    func moveEntryToDay(entryId: UUID, date: Date, index: Int) async throws {
        try await db.write { db in
            
            try DBMealplanEntry
                .find(entryId)
                .update { entry in
                    entry.date = date
                    entry.index = index
                }
                .execute(db)
            
            for entry in entries {
                if entry.id != entryId && entry.index >= index {
                    try DBMealplanEntry
                        .find(entry.id)
                        .update { e in
                            e.index = e.index + 1
                        }
                        .execute(db)
                }
            }
        }
    }
}

private struct DropGap: View {
    let index: Int
    @Binding var hoveringIndex: Int?
    var overrideIsTargeted: Bool = false
    var onDropAt: (_ index: Int, _ recipes: MealplanEntry) async throws -> Void
    
    @State private var isTargeted = false
    @Environment(\.isMealplanDragging) private var isDragging
    
    var body: some View {
        ZStack(alignment: .center) {
            if isDragging {
                Rectangle()
                    .frame(height: 20)
                    .opacity(0.0001)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? .blue : .layer2)
                    .frame(height: isActive ? 135 : 2)
                    .opacity(isActive ? 0.8 : 0.01)
            }
        }
        .animation(.easeInOut, value: isActive)
        .dropDestination(for: MealplanEntry.self) { items, _ in
            Task {
                try? await onDropAt(index, items[0])
            }
            hoveringIndex = nil
            return true
        } isTargeted: { val in
            withAnimation(.easeInOut(duration: 0.12)) {
                isTargeted = val
                hoveringIndex = val ? index : nil
            }
        }
    }
    
    private var isActive: Bool { isTargeted || hoveringIndex == index || overrideIsTargeted }
}

//#Preview {
//
//    @Previewable @Environment(\.calendar) var calendar
//    @Previewable @State var appRouter: AppRouter = .init(initialTab: .mealplan)
//    NavigationStack {
//        ZStack {
//            Color.layer1.ignoresSafeArea()
//            ScrollView {
//                LazyVStack {
//                    MealplanRowView(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
//                    MealplanRowView(for: Date())
//                    MealplanRowView(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
//                    MealplanRowView(for: calendar.date(byAdding: .day, value: 2, to: Date())!)
//                    MealplanRowView(for: calendar.date(byAdding: .day, value: 3, to: Date())!)
//                }
//            }
//        }
//        .safeAreaPadding()
//        .navigationTitle("Mealplans")
//        .preferredColorScheme(.dark)
//        .environment(appRouter)
//    }
//}
