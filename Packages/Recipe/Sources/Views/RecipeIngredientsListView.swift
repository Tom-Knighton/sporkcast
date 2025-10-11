//
//  RecipeIngredientsListView.swift
//  Recipe
//
//  Created by Tom Knighton on 14/09/2025.
//

import SwiftUI
import FoundationModels
import API

public struct RecipeIngredientsListView: View {
    
    @Environment(RecipeViewModel.self) private var viewModel
    public let tint: Color
    @State private var ingredients: [RecipeIngredient] = []
        
    public var body: some View {
        VStack {
            ForEach(ingredients) { ingredient in
                HStack {
                    ZStack {
                        Circle()
                            .frame(width: 25, height: 25)
                        
                        if let emoji = ingredient.emojiDescriptor {
                            Text(emoji)
                                .font(.caption)
                        }
                    }
                    
                    Text(IngredientHighlighter.highlight(ingredient: ingredient, tint: tint))
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
        .safeAreaPadding(.bottom)
        .onAppear {
            if ingredients.isEmpty {
                self.ingredients = viewModel.recipe?.ingredients?.sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
            }
        }
    }
}

@Generable
public struct EmojiResponse {
    public let emoji: String?
}
