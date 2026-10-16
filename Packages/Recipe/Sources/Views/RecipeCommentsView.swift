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
    let showRecipeChat: Bool

    init(showRecipeChat: Bool = false) {
        self.showRecipeChat = showRecipeChat
    }
    
    private var ratings: [RecipeRating] {
        (vm.recipe.ratingInfo?.ratings ?? []).filter { $0.comment != nil }
    }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if vm.tipsAndSummaryGenerating {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Finding useful tips in the reviews…")
                        .font(.subheadline)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RecipeAssistantStyle.surface, in: .rect(cornerRadius: 20))
            }

            if !vm.tipsAndSummaryGenerating, let tip = vm.recipe.summarisedTip, !tip.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("From the cooks", systemImage: "quote.bubble")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button("About this summary", systemImage: "info.circle") {
                            showLLMInfo = true
                        }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    Text(tip)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(RecipeAssistantStyle.surface, in: .rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(RecipeAssistantStyle.border, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }

            if !showRecipeChat, ratings.isEmpty, vm.recipe.summarisedTip == nil, !vm.tipsAndSummaryGenerating {
                ContentUnavailableView("No cooking tips yet", systemImage: "bubble.left.and.bubble.right", description: Text("Reviews and useful tips from other cooks will appear here when this recipe has them."))
            }

            if showRecipeChat {
                Spacer().frame(height: 8)
                RecipeChatView()
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
                Text("What other cooks say")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(ratings) { rating in
                    comment(rating.comment ?? "", rating: rating.rating)
                }
            }
            
            Spacer().frame(height: 8)
        }
        .fontDesign(.default)
        .alert("About review summaries", isPresented: $showLLMInfo) {
            Button(role: .confirm) {}
        } message: {
            Text("Apple Intelligence summarises the reviews attached to this recipe, using Private Cloud Compute when available or an on-device model. The summary can be shared with your Sporkast home. Generated tips can contain mistakes; check the original reviews for context.")
        }

    }
}

extension RecipeCommentsView {
    
    @ContentBuilder
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
    
    @ContentBuilder
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
