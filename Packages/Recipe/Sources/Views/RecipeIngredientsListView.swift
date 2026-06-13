//
//  RecipeIngredientsListView.swift
//  Recipe
//
//  Created by Tom Knighton on 14/09/2025.
//

import SwiftUI
import FoundationModels
import Models

public struct RecipeIngredientsListView: View {
    @Environment(RecipeViewModel.self) private var viewModel
    @State private var ingredients: [RecipeIngredient] = []
    public let tint: Color
    public let completedIngredientIDs: Set<UUID>
    public let showMealplanShoppingTicks: Bool
    public let showIngredientEmojis: Bool

    public init(
        tint: Color,
        completedIngredientIDs: Set<UUID> = [],
        showMealplanShoppingTicks: Bool = false,
        showIngredientEmojis: Bool = true
    ) {
        self.tint = tint
        self.completedIngredientIDs = completedIngredientIDs
        self.showMealplanShoppingTicks = showMealplanShoppingTicks
        self.showIngredientEmojis = showIngredientEmojis
    }
        
    public var body: some View {
        LazyVStack {
            ForEach(ingredients) { ingredient in
                let showCompletionTick = showMealplanShoppingTicks && completedIngredientIDs.contains(ingredient.id)
                HStack {
                    ZStack {
                        if isGeneratingIngredientEmoji || displayedEmoji(for: ingredient) != nil || showCompletionTick {
                            Circle()
                                .frame(width: 25, height: 25)
                        }
                        
                        if isGeneratingIngredientEmoji {
                            ProgressView()
                        } else if showCompletionTick {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                        }

                        if !isGeneratingIngredientEmoji, !showCompletionTick, let emoji = displayedEmoji(for: ingredient) {
                            Text(emoji)
                                .font(.caption)
                        }
                    }
                    
                    Text(
                        ShoppingImportIngredientFormatter.highlightedIngredientText(
                            for: ingredient,
                            scale: viewModel.recipe.ingredientScale,
                            unitSystem: viewModel.recipe.ingredientUnitSystem,
                            tint: tint
                        )
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Material.thin)
                .clipShape(.rect(cornerRadius: 10))
            }
            
            Spacer().frame(height: 8)
        }
        .onAppear {
            updateIngredients(from: viewModel.recipe.ingredientSections)
        }
        .onChange(of: viewModel.recipe.ingredientSections) { _, sections in
            updateIngredients(from: sections)
        }
    }

    private var isGeneratingIngredientEmoji: Bool {
        showIngredientEmojis && viewModel.ingredientsGenerating
    }

    private func displayedEmoji(for ingredient: RecipeIngredient) -> String? {
        showIngredientEmojis ? ingredient.emoji : nil
    }

    private func updateIngredients(from sections: [RecipeIngredientGroup]) {
        ingredients = sections
            .flatMap(\.ingredients)
            .sorted(by: { $0.sortIndex < $1.sortIndex })
    }
}

@Generable
public struct EmojiResponse {
    public let emoji: String?
}
