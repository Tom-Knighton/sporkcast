//
//  RecipePage.swift
//  Recipe
//
//  Created by Tom Knighton on 24/08/2025.
//

import SwiftUI
import Design
import API

public struct RecipePage: View {
    
    @State private var offset: CGFloat = 0
    @State private var showNavTitle = false
    @Environment(\.colorScheme) private var scheme
    
    @Environment(\.networkClient) private var client
    @State private var recipe: Recipe?
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    if let recipe {
                        RecipeHeadingView(recipe.imageUrl ?? "")
                        
                        VStack(alignment: .leading) {
                            Text(recipe.author ?? "")
                                .font(.footnote.weight(.heavy))
                                .opacity(0.6)
                            Text(recipe.title)
                                .font(.title.weight(.bold))
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(
                                                key: TitleBottomYKey.self,
                                                value: proxy.frame(in: .named("scroll")).maxY
                                            )
                                    }
                                )
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, -16)
                        .colorScheme(.dark)
                        
                        VStack {
                            HStack {
                                image(recipe.imageUrl ?? "")
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(.rect(cornerRadius: 3))
                                VStack(alignment: .leading) {
                                    Text("View Recipe Source")
                                        .font(.footnote.weight(.bold))
                                        .opacity(0.6)

                                    Text(recipe.title)
                                        .font(.body.bold())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Image(systemName: "link.circle.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Material.thin)
                            .clipShape(.rect(cornerRadius: 10))
                            .shadow(radius: 3)
                            
                            HStack {
                                Group {
                                    HStack {
                                        if let prepTime = recipe.minutesToPrepare {
                                            Image(systemName: "fork.knife.circle.fill")
                                            Text("Prep: \(prepTime.formatted())m")
                                        }
                                    }
                                    HStack {
                                        if let cookTime = recipe.minutesToCook {
                                            Image(systemName: "frying.pan.fill")
                                            Text("Cook: \(cookTime.formatted())m")
                                        }
                                    }
                                    HStack {
                                        if let rating = recipe.ratings.overallRating {
                                            Text(rating.formatted())
                                            Image(systemName: "star.fill")
                                        }
                                    }
                                }
                                .font(.footnote)
                                .padding()
                                .background(Material.thin)
                                .clipShape(.rect(cornerRadius: 10))
                                .shadow(radius: 3)
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self, of: { geo in
                return geo.contentOffset.y + geo.contentInsets.top
            }, action: { new, old in
                offset = new
            })
        }
        .ignoresSafeArea()
        .task(id: "load") {
            if recipe != nil { return }
            
            self.recipe = try? await client.post(Recipes.uploadFromUrl(url: "https://beatthebudget.com/recipe/chicken-katsu-curry/"))
        }
        .background(
            image(recipe?.imageUrl ?? "")
                .aspectRatio(contentMode: .fill)
                .scaleEffect(2)
                .blur(radius: scheme == .dark ? 100 : 64)
                .ignoresSafeArea()
        )
        .onPreferenceChange(TitleBottomYKey.self) { bottom in
            let collapsed = bottom < 0
            if collapsed != showNavTitle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavTitle = collapsed
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(recipe?.title ?? "")
                    .font(.headline)
                    .opacity(showNavTitle ? 1 : 0)
                    .accessibilityHidden(!showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: showNavTitle)
            }
        }
    }
    
    @ViewBuilder
    private func image(_ recipeUrl: String) -> some View {
        AsyncImage(url: URL(string: recipeUrl)) { img in
            img
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        RecipePage()
            .withPreviewEnvs()
    }

}
