//
//  RecipeHeadingView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI

public struct RecipeHeadingView<Image: View>: View {
    
    private let image: Image
    private let pullDown: CGFloat
    
    public init(pullDown: CGFloat = 0, @ContentBuilder imageContent: () -> Image) {
        self.pullDown = max(0, pullDown)
        self.image = imageContent()
    }
    
    public var body: some View {
        Color.clear
            .frame(height: 400)
            .background {
                GeometryReader { reader in
                    let height = reader.size.height + pullDown
                    ZStack(alignment: .bottom) {
                        image
                            .frame(width: reader.size.width, height: height)
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
                    .frame(width: reader.size.width, height: height)
                    .offset(y: -pullDown)
                    .compositingGroup()
                }
                .ignoresSafeArea(.container, edges: [.top, .trailing])
            }
    }
}
