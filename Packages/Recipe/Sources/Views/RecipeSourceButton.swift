//
//  RecipeSourceButton.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API
import UIKit


public struct RecipeSourceButton<RecipeImage: View>: View {
    
    @Environment(\.colorScheme) private var colorScheme
    private let recipe: Recipe
    private let color: Color
    private let image: RecipeImage
    
    public init (_ recipe: Recipe, with color: Color = .clear, @ViewBuilder image: () -> RecipeImage) {
        self.recipe = recipe
        self.color = color
        self.image = image()
    }
    
    public var body: some View {
        Button(action: {}) {
            HStack {
                image
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: 3))

                VStack(alignment: .leading) {
                    Text("View Recipe Source")
                        .font(.footnote.weight(.bold))
                        .opacity(0.6)
                    
                    Text(recipe.title)
                        .font(.body.bold())
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "link.circle.fill")
            }
            .contentShape(.rect)
            .frame(maxWidth: .infinity)
            .padding(.all, 6)
            .clipped()
            .shadow(radius: 3)
            
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .tint(color)
    }
}

