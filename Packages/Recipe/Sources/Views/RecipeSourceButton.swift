//
//  RecipeSourceButton.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API
import UIKit


public struct RecipeSourceButton: View {
    
    @Environment(\.colorScheme) private var colorScheme
    private let recipe: Recipe
    private let color: Color
    
    public init (_ recipe: Recipe, with color: Color = .clear) {
        self.recipe = recipe
        self.color = color
    }
    
    public var body: some View {
        Button(action: {}) {
            HStack {
                RecipeImage(recipe)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: 3))
                
                
                
                VStack(alignment: .leading) {
                    Text("View Recipe Source")
                        .font(.footnote.weight(.bold))
                        .opacity(0.6)
                    
                    Text(recipe.title)
                        .font(.body.bold())
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

