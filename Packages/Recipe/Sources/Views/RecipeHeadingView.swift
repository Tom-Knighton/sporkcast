//
//  RecipeHeadingView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI

public struct RecipeHeadingView<Image: View>: View {
    
    private let image: Image
    
    public init (@ContentBuilder imageContent: () -> Image) {
        self.image = imageContent()
    }
    
    public var body: some View {
        Color.clear
            .frame(height: 400)
            .background {
                GeometryReader { reader in
                    ZStack(alignment: .bottom) {
                        image
                            .frame(width: reader.size.width, height: reader.size.height)
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
                    .frame(width: reader.size.width, height: reader.size.height)
                    .compositingGroup()
                }
                .ignoresSafeArea(.container, edges: [.top, .trailing])
            }
    }
}
