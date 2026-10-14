import SwiftUI

struct RecipeCookingContent<Controls: View>: View {
    let usesColumns: Bool
    let tint: Color
    let completedIngredientIDs: Set<UUID>
    let showMealplanShoppingTicks: Bool
    let showIngredientEmojis: Bool
    @ContentBuilder let controls: () -> Controls

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: usesColumns ? 16 : 24) {
                if usesColumns {
                    Text("Ingredients").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                }
                VStack(alignment: .leading, spacing: 0) {
                    controls()
                }
                RecipeIngredientsListView(
                    tint: tint,
                    completedIngredientIDs: completedIngredientIDs,
                    showMealplanShoppingTicks: showMealplanShoppingTicks,
                    showIngredientEmojis: showIngredientEmojis
                )
                .tint(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if usesColumns {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Steps").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    RecipeStepsView(
                        tint: tint,
                        completedIngredientIDs: completedIngredientIDs,
                        showMealplanShoppingTicks: showMealplanShoppingTicks,
                        showIngredientEmojis: showIngredientEmojis
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
