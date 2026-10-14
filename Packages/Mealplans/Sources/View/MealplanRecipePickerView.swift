import Design
import RecipesList
import SwiftUI

struct MealplanRecipePickerView: View {
    let day: Date
    let isAddingEntry: Bool
    let confirmation: String?
    let onRecipeSelected: (UUID) async -> Void
    let onQuickSelect: (Date) async -> Void
    let onRandomRecipeSelected: (UUID, Date) async throws -> Void
    let onNoteSaved: (String, Date) async -> Bool
    var onClose: (() -> Void)? = nil

    @State private var showingRandomWheel = false
    @State private var showingNote = false
    @State private var actionDay = Date.now

    var body: some View {
        Group {
            if let onClose {
                NavigationStack {
                    RecipePickerPage(onRecipeSelected, title: "Add a Meal")
                        .disabled(isAddingEntry)
                        .toolbar {
                            ToolbarItem { Button(role: .close, action: onClose) }
                        }
                }
            } else {
                RecipePickerPage(onRecipeSelected, isEmbedded: true) {
                    pickerHeader
                }
                .disabled(isAddingEntry)
                .ignoresSafeArea(.container, edges: .top)
            }
        }
        .sheet(isPresented: $showingRandomWheel) {
            RandomMealWheelSheet { recipe in
                try await onRandomRecipeSelected(recipe.id, actionDay)
            }
            .presentationDetents([.fraction(0.92), .large])
        }
        .sheet(isPresented: $showingNote) {
            NoteSheetView(initialText: "", title: "Add Note") { text in
                Task {
                    if await onNoteSaved(text, actionDay) { showingNote = false }
                }
            } onCancel: {
                showingNote = false
            }
            .disabled(isAddingEntry)
            .interactiveDismissDisabled(isAddingEntry)
            .presentationDetents([.medium, .large])
        }
    }

    private var pickerHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a Meal")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text(day.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MealplanPickerActionsView(
                onQuickSelect: { Task { await onQuickSelect(day) } },
                onRandomMeal: { actionDay = day; showingRandomWheel = true },
                onAddNote: { actionDay = day; showingNote = true }
            )
            .disabled(isAddingEntry)
            if isAddingEntry {
                ProgressView("Adding…")
            } else if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 20)
    }
}
