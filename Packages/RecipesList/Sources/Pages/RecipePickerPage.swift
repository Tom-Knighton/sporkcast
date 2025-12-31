//
//  RecipePickerPage.swift
//  RecipesList
//
//  Created by Tom Knighton on 20/11/2025.
//

import SwiftUI
import Models
import Environment

public struct RecipePickerPage: View {
    
    @State private var repository = RecipesRepository()
    private let onRecipeSelected: (UUID) async -> Void
    
    public init(_ onRecipeSelected: @escaping (UUID) async -> Void) {
        self.onRecipeSelected = onRecipeSelected
    }
    
    public var body: some View {
        List(repository.recipes) { recipe in
            Button(action: { Task { await self.onRecipeSelected(recipe.id) } }) {
                RecipeCardView(recipe: recipe, enablePreview: false)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .navigationTitle("Select A Recipe")
    }
}
