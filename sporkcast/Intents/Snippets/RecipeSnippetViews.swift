//
//  RecipeSnippetViews.swift
//  sporkcast
//
//  Created by Tom Knighton on 05/07/2026.
//

import AppIntents
import SwiftUI
import UIKit

@available(anyAppleOS 27.0, *)
struct RecipeResultsSnippetView: View {
    let title: String
    let recipes: [RecipeEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if recipes.isEmpty {
                Text("No recipes found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recipes) { recipe in
                    Button(intent: OpenRecipeIntent(target: recipe)) {
                        HStack(spacing: 12) {
                            RecipeSnippetImage(recipe: recipe)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)

                                Text(recipe.displaySubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

@available(anyAppleOS 27.0, *)
private struct RecipeSnippetImage: View {
    let recipe: RecipeEntity

    var body: some View {
        Group {
            if let imageData = recipe.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let imageUrl = recipe.imageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 48, height: 48)
        .background(.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var fallback: some View {
        Image(systemName: "fork.knife")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

@available(anyAppleOS 27.0, *)
struct RecipeDetailSnippetView: View {
    let recipe: RecipeEntity
    let ingredients: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(.headline)

            Text(recipe.displaySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(ingredients.prefix(6).enumerated()), id: \.offset) { _, ingredient in
                        Text(ingredient)
                            .font(.caption)
                    }
                }
            }

            Button(intent: OpenRecipeIntent(target: recipe)) {
                Label("Open Recipe", systemImage: "arrow.up.forward.app")
            }
        }
        .padding()
    }
}
