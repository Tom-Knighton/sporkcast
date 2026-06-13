//
//  RecipeTitleView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import Models

public struct RecipeTitleView: View {
    private let title: String
    private let author: String?
    @Binding private var showNavTitle: Bool
    
    public init(title: String, author: String?, showNavTitle: Binding<Bool>) {
        self.title = title
        self.author = author
        self._showNavTitle = showNavTitle
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(author ?? "")
                .font(.footnote.weight(.heavy))
                .opacity(0.6)
            Text(title)
                .font(.title.weight(.bold))
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: TitleBottomYKey.self,
                                value: Optional(proxy.frame(in: .named("recipeScroll")).maxY)
                            )
                    }
                )
            Spacer()
        }
        .onPreferenceChange(TitleBottomYKey.self) { bottom in
            guard let bottom, bottom.isFinite else { return }
            let collapsed = max(0, bottom) < 75
            if collapsed != showNavTitle {
                showNavTitle = collapsed
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, -16)
        .colorScheme(.dark)
    }
}
