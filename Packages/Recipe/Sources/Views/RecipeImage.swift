//
//  RecipeImage.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API

public struct RecipeImage: View {
    
    private let recipeUrl: String
    
    public init (_ recipe: Recipe) {
        self.recipeUrl = recipe.imageUrl ?? ""
    }
    
    public var body: some View {
        AsyncImage(url: URL(string: recipeUrl)) { img in
            img
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            EmptyView()
        }
    }
}
