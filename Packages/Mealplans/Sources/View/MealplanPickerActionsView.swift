import SwiftUI

struct MealplanPickerActionsView: View {
    let onQuickSelect: () -> Void
    let onRandomMeal: () -> Void
    let onAddNote: () -> Void

    var body: some View {
        GlassEffectContainer {
            ViewThatFits(in: .horizontal) {
                HStack {
                    actions
                }
                VStack(alignment: .leading) {
                    actions
                }
            }
        }
        .labelStyle(.titleOnly)
        .buttonStyle(.glass)
        .controlSize(.small)
    }

    @ContentBuilder
    private var actions: some View {
        Button("Quick Select", systemImage: "arrow.trianglehead.swap", action: onQuickSelect)
        Button("Random Meal", systemImage: "fireworks", action: onRandomMeal)
        Button("Add Note", systemImage: "pencil", action: onAddNote)
    }
}
