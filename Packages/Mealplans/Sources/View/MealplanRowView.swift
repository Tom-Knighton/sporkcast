//
//  MealplanRowView.swift
//  Mealplans
//
//  Created by Tom Knighton on 17/11/2025.
//

import SwiftUI
import Design
import RecipesList
import Models
import Environment

private struct NoteDraft: Identifiable, Equatable {
    let id: UUID?
    var text: String
}

public struct MealplanRowView: View {
    
    @Environment(\.homeServices) private var homes
    @Environment(ZoomManager.self) private var zm
    @Environment(AppRouter.self) private var router
    @Environment(\.calendar) private var calendar
    @Environment(MealplanRepository.self) private var repository
    
    @State private var isRowTargeted = false
    @State private var hoveringIndex: Int? = nil
    @State private var draggingId: UUID? = nil
    @Binding private var isDragging: Bool
    
    @State private var showAddSheet: Bool = false
    @State private var noteDraft: NoteDraft? = nil
    
    @State private var recipeImages: [UUID: UIImage] = [:]
    
    public let day: Date
    public let entries: [MealplanEntry]
    public let currentDate: Date
    
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
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 10) )
                .allowsHitTesting(false)
            VStack(spacing: 0) {
                HStack {
                    Text(dayTitle(for: day))
                        .bold()
                    Spacer()
                    
                    if !isInPast {
                        Menu {
                            Button(action: { self.showAddSheet = true }) {
                                Label("Add Meal", systemImage: "plus.circle")
                            }
                            Button(action: { Task { try? await insertRandomMeal() } }) {
                                Label("Random Meal", systemImage: "arrow.trianglehead.swap")
                            }
                            Divider()
                            
                            Button(action: { self.noteDraft = .init(id: nil, text: "")}) {
                                Label("Add Note", systemImage: "pencil")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.white, .blue)
                                .font(.title)
                                .frame(width: 28, height: 28)
                                .contentShape(.rect)
                                .fixedSize()
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
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
                    VStack(spacing: 0) {
                        if draggingId != entry.id {
                            rowView(for: entry, idx)
                            
                            DropGap(index: idx + 1, hoveringIndex: $hoveringIndex) { insertIndex, droppedEntry in
                                self.draggingId = nil
                                self.isDragging = false
                                try await self.moveEntryToDay(entryId: droppedEntry.id, date: day, index: insertIndex)
                            }
                            .containerShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .contentShape(.rect)
            .fontDesign(.rounded)
            .frame(minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: .init(lineWidth: isInPast ? 2 : 4, dash: isInPast ? [5] : []))
                    .fill(isInPast ? .gray : calendar.isDateInToday(day) ? .blue : .clear)
            }
            .overlay {
                if isInPast {
                    Color.gray.opacity(0.25).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 10))
            .onChange(of: self.draggingId, { _, newValue in
                self.isDragging = newValue != nil
            })
            .sheet(isPresented: $showAddSheet) {
                selectorSheetView()
            }
            .sheet(item: $noteDraft) { draft in
                NoteSheetView(initialText: draft.text, title: draft.id == nil ? "Add Note" : "Edit Note") { newText in
                    Task {
                        await self.upsertNote(id: draft.id, text: newText)
                    }
                } onCancel: {
                    self.noteDraft = nil
                }
                .presentationDetents([.fraction(0.2)])
            }
            .id(currentDate)
        }
    }
    
    @ViewBuilder
    private func rowView(for entry: MealplanEntry, _ idx: Int) -> some View {
        if let recipe = entry.recipe {
            let cached = recipeImages[recipe.id]
            
            RecipeCardView(
                recipe: recipe,
                enablePreview: false,
                preloadedImage: cached,
                onImageLoaded: { img in
                    recipeImages[recipe.id] = img
                }
            )
            .padding(4)
            .matchedTransitionSource(id: "zoom-\(recipe.id.uuidString)-\(entry.id.uuidString)", in: zm.zoomNamespace)
            .containerShape(.rect(cornerRadius: 10))
            .transition(.opacity)
            .draggable(entry) {
                mealPreview(for: entry)
                    .onAppear { draggingId = entry.id }
            }
            .contextMenu {
                Button {
                    draggingId = nil
                    router.navigateTo(.recipe(recipe: recipe))
                } label: {
                    Text("Open Recipe")
                }
                Divider()
                Button(role: .destructive) { Task { try? await removeEntry(id: entry.id) } }  label: {
                    Label("Remove meal", systemImage: "trash")
                }
            } preview: {
                mealPreview(for: entry)
            }
            .onTapGesture {
                self.draggingId = nil
                self.router.navigateTo(.recipe(recipe: recipe, zoomSuffix: entry.id.uuidString))
            }
        } else if let note = entry.note {
            NoteView(text: note)
                .draggable(entry) {
                    NoteView(text: note)
                        .onAppear {
                            self.draggingId = entry.id
                        }
                }
                .transition(.opacity)
                .padding(4)
                .containerShape(.rect(cornerRadius: 10))
                .contextMenu {
                    Button(action: { self.noteDraft = .init(id: entry.id, text: note)}) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive, action: {
                        Task { try? await removeEntry(id: entry.id) }
                    }) {
                        Label("Remove note", systemImage: "trash")
                    }
                }
        }
    }
    
    @ViewBuilder
    private func mealPreview(for entry: MealplanEntry) -> some View {
        if let recipe = entry.recipe {
            RecipeCardView(
                recipe: recipe,
                enablePreview: false,
                preloadedImage: recipeImages[recipe.id]
            )
            .containerShape(.rect(cornerRadius: 10))
            .frame(width: 320, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let note = entry.note {
            NoteView(text: note)
                .frame(width: 320, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    @ViewBuilder
    private func selectorSheetView() -> some View {
        NavigationStack {
            RecipePickerPage() { selectedId in
                self.showAddSheet.toggle()
                do {
                    try await repository.addRecipeEntry(date: day, index: entries.count, recipeId: selectedId, homeId: homes.home?.id)
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
    
    func insertRandomMeal() async throws {
        try await repository.insertRandomMeal(date: day, index: entries.count, homeId: homes.home?.id)
    }
    
    func removeEntry(id: UUID) async throws {
        try await repository.deleteEntry(id: id)
    }
    
    func moveEntryToDay(entryId: UUID, date: Date, index: Int) async throws {
        try await repository.moveEntry(entryId: entryId, to: date, index: index, existingEntries: entries)
    }
    
    func upsertNote(id: UUID?, text: String) async {
        defer { self.noteDraft = nil }
        
        do {
            if let id {
                try await repository.updateNote(id: id, text: text)
            } else {
                try await repository.addNoteEntry(date: day, index: entries.count, text: text, homeId: homes.home?.id)
            }
        } catch {
            print(error)
        }
    }
}

private struct DropGap: View {
    let index: Int
    @Binding var hoveringIndex: Int?
    var overrideIsTargeted: Bool = false
    var onDropAt: (_ index: Int, _ recipes: MealplanEntry) async throws -> Void
    
    @State private var isTargeted = false
    @State private var successTrigger: Bool = false
    @Environment(\.isMealplanDragging) private var isDragging
    
    var body: some View {
        ZStack(alignment: .center) {
            if isDragging {
                ConcentricRectangle()
                    .stroke(.gray.opacity(0.75), style: .init(lineWidth: 1, dash: [5]))
                    .fill(isActive ? .blue : .layer2.opacity(0.3))
                    .padding(4)
                    .frame(height: isActive ? 135 : 50)
                
                Label("Drop Here", systemImage: "plus.app")
                    .bold(isActive)
                    .foregroundStyle(isActive ? Color.white : Color.primary)
            }
        }
        .fontDesign(.rounded)
        .animation(.easeInOut, value: isActive)
        .containerShape(.rect(cornerRadius: 10))
        .sensoryFeedback(.selection, trigger: isActive)
        .sensoryFeedback(.success, trigger: successTrigger)
        .dropDestination(for: MealplanEntry.self) { items, _ in
            Task {
                try? await onDropAt(index, items[0])
                self.successTrigger.toggle()
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

#Preview {
    @Previewable @Namespace var zm
    @Previewable @State var isDraggingEntry = false

    let calendar = Calendar(identifier: .iso8601)
    let today = calendar.startOfDay(for: .now)

    let entries = [
        MealplanEntry(
            id: UUID(),
            date: today,
            index: 0,
            note: "Prep veggies early",
            recipe: Recipe(
                id: UUID(),
                title: "Preview Pasta",
                description: "A speedy weekday pasta with tomato and basil.",
                author: "Preview Chef",
                sourceUrl: "https://example.com/pasta",
                image: .init(imageThumbnailData: nil, imageUrl: "https://www.allrecipes.com/thmb/xcOdImFBdut09lTsPnOxIjnv-2E=/0x512/filters:no_upscale():max_bytes(150000):strip_icc()/228823-quick-beef-stir-fry-DDMFS-4x3-1f79b031d3134f02ac27d79e967dfef5.jpg"),
                timing: .init(totalTime: 25, prepTime: 10, cookTime: 15),
                serves: "2",
                ratingInfo: .init(overallRating: 4.5, summarisedRating: "Fresh and light", ratings: []),
                dateAdded: .now,
                dateModified: .now,
                ingredientSections: [],
                stepSections: [],
                dominantColorHex: nil,
                homeId: nil
            )
        ),
        MealplanEntry(
            id: UUID(),
            date: today,
            index: 1,
            note: "I'm a note",
            recipe: nil
        ),
    ]

    let repository = MealplanRepository()
    NavigationStack {
        ZStack {
            Color.layer1.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 12) {
                    MealplanRowView(for: calendar.date(byAdding: .day, value: -1, to: today)!, with: [], currentDate: today, isDraggingEntry: $isDraggingEntry)
                    MealplanRowView(for: today, with: entries, currentDate: today, isDraggingEntry: $isDraggingEntry)
                    MealplanRowView(for: calendar.date(byAdding: .day, value: 1, to: today)!, with: [], currentDate: today, isDraggingEntry: $isDraggingEntry)
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
        .environment(\.isMealplanDragging, isDraggingEntry)
        .environment(repository)
        .navigationTitle("Mealplans")
        .environment(AppRouter(initialTab: .mealplan))
        .environment(ZoomManager(zm))
        .environment(\.homeServices, MockHouseholdService())
    }
}
