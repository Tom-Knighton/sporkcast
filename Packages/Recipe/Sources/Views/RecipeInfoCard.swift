//
//  RecipeInfoCard.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API

public struct RecipeInfoCard: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let recipe: Recipe
    private let title: String
    private let image: String
    
    public init (_ recipe: Recipe, title: String, image: String) {
        self.recipe = recipe
        self.title = title
        self.image = image
    }
    
    public var body: some View {
        HStack {
            Image(systemName: image)
            Text(title)
        }
        .padding(10)
        .background(colorScheme == .dark ? .ultraThinMaterial : .thinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 3)
    }
}
