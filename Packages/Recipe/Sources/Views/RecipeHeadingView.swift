//
//  RecipeHeadingView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI

public struct RecipeHeadingView<Image: View>: View {
    
    private let image: Image
    
    public init (@ViewBuilder imageContent: () -> Image) {
        self.image = imageContent()
    }
    
    public var body: some View {
        GeometryReader { reader in
            ZStack(alignment: .bottom) {
                image
                    .frame(height: 400)
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .black, location: 0.99),
                        .init(color: .black, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.destinationOut)
                .allowsHitTesting(false)
                .frame(height: 200)
            }
            .ignoresSafeArea()
            .compositingGroup()
        }
        .frame(height: 400)
    }
}
