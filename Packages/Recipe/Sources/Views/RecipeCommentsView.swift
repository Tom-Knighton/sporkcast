//
//  RecipeCommentsView.swift
//  Recipe
//
//  Created by Tom Knighton on 01/01/2026.
//

import Models
import SwiftUI

struct RecipeCommentsView: View {
    
    @Environment(RecipeViewModel.self) private var vm
    
    private var ratings: [RecipeRating] {
        (vm.recipe.ratingInfo?.ratings ?? []).filter { $0.comment != nil }
    }
 
    var body: some View {
        VStack {
            if let overallRating = vm.recipe.ratingInfo?.overallRating {
                VStack(spacing: 8) {
                    starView(overallRating, max: 5)
                    
                    if let total = vm.recipe.ratingInfo?.totalRatings, total > 0 {
                        Text("Based on \(total) ratings")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect()
            }
            
            if !ratings.isEmpty {
                Spacer().frame(height: 16)
                Text("Reviews:")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(ratings) { rating in
                    comment(rating.comment ?? "", rating: rating.rating)
                }
            }
        }
        .fontDesign(.rounded)
    }
}

extension RecipeCommentsView {
    
    @ViewBuilder
    private func starView(_ rating: Double, max: Int = 5) -> some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 4) {
                ForEach(0..<max, id: \.self) { _ in
                    Image(systemName: "star")
                }
            }
            
            HStack(spacing: 4) {
                ForEach(0..<max, id: \.self) { _ in
                    Image(systemName: "star.fill")
                }
            }
            .mask(
                GeometryReader { geo in
                    Rectangle()
                        .frame(
                            width: geo.size.width * CGFloat(min(rating / Double(max), 1))
                        )
                }
            )
        }
    }
    
    @ViewBuilder
    private func comment(_ comment: String, rating: Int?) -> some View {
        VStack(spacing: 8) {
            
            if let rating {
                HStack {
                    starView(Double(rating), max: 5)
                        .font(.caption)
                    
                    Spacer()
                }
            }
            
            Text(comment)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(.regular, in: .rect(corners: .concentric(minimum: .fixed(10))))
    }
}
