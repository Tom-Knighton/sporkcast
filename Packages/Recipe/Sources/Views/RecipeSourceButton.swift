//
//  RecipeSourceButton.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API
import UIKit
import RecipeImporting


public struct RecipeSourceButton<RecipeImage: View>: View {
    
    @Environment(RecipeViewModel.self) private var vm
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openUrl
    private let color: Color
    private let image: RecipeImage
    
    public init (with color: Color = .clear, @ViewBuilder image: () -> RecipeImage) {
        self.color = color
        self.image = image()
    }
    
    public var body: some View {
        Group {
            if let sourceURL = URL(string: vm.recipe.sourceUrl), SyntheticSourceURL.isExternalWebURL(vm.recipe.sourceUrl) {
                Button(action: {
                    self.openUrl(sourceURL)
                }) {
                    sourceRow(title: "View Recipe Source", subtitle: vm.recipe.title, icon: "link.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                sourceRow(title: "Imported Recipe", subtitle: "Imported into Sporkcast", icon: "square.and.arrow.down.fill")
                    .opacity(0.92)
            }
        }
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .tint(color)
    }

    @ViewBuilder
    private func sourceRow(title: String, subtitle: String, icon: String) -> some View {
        HStack {
            image
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 3))

            VStack(alignment: .leading) {
                Text(title)
                    .font(.footnote.weight(.bold))
                    .opacity(0.6)

                Text(subtitle)
                    .font(.body.bold())
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: icon)
        }
        .contentShape(.rect)
        .frame(maxWidth: .infinity)
        .padding(.all, 6)
        .clipped()
        .shadow(radius: 3)
    }
}
