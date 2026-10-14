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
    @Binding private var titleBottom: CGFloat?
    
    public init(title: String, author: String?, titleBottom: Binding<CGFloat?>) {
        self.title = title
        self.author = author
        self._titleBottom = titleBottom
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text(author ?? "")
                .font(.footnote.weight(.heavy))
                .opacity(0.6)
            Text(title)
                .font(.title.weight(.bold))
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.frame(in: .named("recipeContent")).maxY
                } action: { bottom in
                    titleBottom = bottom
                }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, -16)
        .colorScheme(.dark)
    }
}
