//
//  RecipeTitleView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API

public struct RecipeTitleView: View {
    private let recipe: Recipe
    
    public init (for recipe: Recipe) {
        self.recipe = recipe
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(recipe.author ?? "")
                .font(.footnote.weight(.heavy))
                .opacity(0.6)
            Text(recipe.title)
                .font(.title.weight(.bold))
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: TitleBottomYKey.self,
                                value: proxy.frame(in: .named("scroll")).maxY
                            )
                    }
                )
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, -16)
        .colorScheme(.dark)
    }
}
