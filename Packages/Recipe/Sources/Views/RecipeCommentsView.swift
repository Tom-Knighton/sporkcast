//
//  RecipeCommentsView.swift
//  Recipe
//
//  Created by Tom Knighton on 01/01/2026.
//

import Models
import SwiftUI
import Design

struct RecipeCommentsView: View {
    
    @State private var showLLMInfo: Bool = false
    @Environment(RecipeViewModel.self) private var vm
    
    private var ratings: [RecipeRating] {
        (vm.recipe.ratingInfo?.ratings ?? []).filter { $0.comment != nil }
    }
 
    var body: some View {
        VStack {
            if vm.tipsAndSummaryGenerating {
                HStack {
                    Text("Generating summary")
                    Image(systemName: "ellipsis")
                        .symbolEffect(.variableColor.cumulative.hideInactiveLayers, options: .repeat(.continuous), isActive: true)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.interactive(), in: .containerRelative)
                .intelligenceBackground(in: .containerRelative)
                .transition(.blurReplace)
            }
            
            if !vm.tipsAndSummaryGenerating, let tip = vm.recipe.summarisedTip {
                VStack {
                    Text(tip)
                    
                    HStack {
                        Spacer()
                        Button(action: { self.showLLMInfo = true }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .intelligenceBackground(in: .rect(cornerRadius: 10), animated: false)
                .transition(.blurReplace)
            }
            
            if let overallRating = vm.recipe.ratingInfo?.overallRating {
                VStack(spacing: 8) {
                    starView(overallRating, max: 5)
                    
                    if let total = vm.recipe.ratingInfo?.totalRatings, total > 0 {
                        Text("Based on \(total) ratings")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect(.regular, in: .rect(corners: .concentric(minimum: 20)))
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
            
            Spacer().frame(height: 8)
        }
        .fontDesign(.rounded)
        .alert("Info", isPresented: $showLLMInfo) {
            Button(role: .confirm) {}
        } message: {
            Text("Sporkast uses your device's (or someone in your Sporkast home's) built-in Apple Intelligence to generate a 'summary' of user reviews for this recipe. It is not trained on any external data - and only the generated summary is stored in your iCloud storage.")
        }

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
        .background(Material.regular)
        .clipShape(.rect(corners: .concentric(minimum: 20)))
    }
}
