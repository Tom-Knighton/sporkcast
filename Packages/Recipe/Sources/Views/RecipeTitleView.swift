//
//  RecipeTitleView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import Models

public struct RecipeTitleView: View {
    
    @Environment(RecipeViewModel.self) private var vm
    @Binding private var showNavTitle: Bool
    
    public init (showNavTitle: Binding<Bool>) {
        self._showNavTitle = showNavTitle
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(vm.recipe.author ?? "")
                .font(.footnote.weight(.heavy))
                .opacity(0.6)
            Text(vm.recipe.title)
                .font(.title.weight(.bold))
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: TitleBottomYKey.self,
                                value: proxy.frame(in: .named("recipeScroll")).maxY
                            )
                    }
                )
            Spacer()
        }
        .onPreferenceChange(TitleBottomYKey.self) { bottom in
            let collapsed = max(0, bottom) < 75
            if collapsed != showNavTitle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavTitle = collapsed
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, -16)
        .colorScheme(.dark)
    }
}
