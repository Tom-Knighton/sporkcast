//
//  RecipeHeadingView.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI

public struct RecipeHeadingView: View {
    
    @State private var imageUrl: String
    
    public init (_ imageUrl: String) {
        self._imageUrl = State(wrappedValue: imageUrl)
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            image()
                .frame(height: 400)
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
        .stretchy()
    }
    
    
    @ViewBuilder
    private func image() -> some View {
        AsyncImage(url: URL(string: imageUrl)) { img in
            img
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            EmptyView()
        }
        .frame(height: 400)
        .clipped()
        
    }
}
