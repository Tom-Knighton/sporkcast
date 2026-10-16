import SwiftUI

struct MealplanRecipeAdditionBar: View {
    let recipeTitle: String
    let day: Date
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipeTitle)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Choose a day above, then add this recipe.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                .foregroundStyle(.secondary)
            Button(action: onAdd) {
                HStack {
                    if isAdding {
                        ProgressView()
                    }
                    Text(isAdding ? "Adding…" : "Add to Meal Plan")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAdding)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
