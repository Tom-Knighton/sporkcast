//
//  RecipePage.swift
//  Recipe
//
//  Created by Tom Knighton on 24/08/2025.
//

import SwiftUI
import Design
import Models
import SwiftData
import API
import SQLiteData
import Environment

public struct RecipePage: View {
    
    @Environment(\.colorScheme) private var scheme
    @Environment(\.networkClient) private var client
    
    @State private var viewModel: RecipeViewModel
    
    public init(_ recipe: Recipe) {
        print("View init")
        self.viewModel = .init(recipe: recipe)
        self.viewModel.dominantColour = Color(hex: recipe.dominantColorHex ?? "") ?? .clear
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    RecipeHeadingView {
                        image()
                            .mask(Rectangle().ignoresSafeArea(edges: .top))
                    }
                    .stretchy()
                    .ignoresSafeArea()
                    
                    RecipeTitleView(showNavTitle: $viewModel.showNavTitle)
                    
                    VStack {
                        
                        Spacer().frame(height: 20)
                        
                        HStack(spacing: 24) {
                            if let totalTime = viewModel.recipe.timing.totalTime {
                                VStack(alignment: .leading) {
                                    Text("Total Time")
                                        .font(.caption.weight(.heavy))
                                        .opacity(0.7)
                                        .textCase(.uppercase)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("\(totalTime, specifier: "%.0f") mins")
                                        .bold()
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                }
                                Divider()
                            }
                            
                            if let cookingMins = viewModel.recipe.timing.cookTime {
                                VStack(alignment: .leading) {
                                    Text("Cooking Time")
                                        .font(.caption.weight(.heavy))
                                        .opacity(0.7)
                                        .textCase(.uppercase)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text("\(cookingMins, specifier: "%.0f") mins")
                                        .bold()
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                }
                                Divider()
                                    .overlay(Material.bar)
                                    .opacity(0.68)
                            }
                            
                            if let serves = viewModel.recipe.serves {
                                VStack(alignment: .leading) {
                                    Text("Serves")
                                        .font(.caption.weight(.heavy))
                                        .opacity(0.7)
                                        .textCase(.uppercase)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text(serves)
                                        .bold()
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Spacer().frame(height: 20)
                        
                        RecipeSourceButton(with: viewModel.dominantColour) {
                            image()
                        }
                        
                        Spacer().frame(height: 20)
                        HStack {
                            Picker("", selection: $viewModel.segment) {
                                Text("Ingredients")
                                    .tag(1)
                                Text("Directions").tag(2)
                            }
                            .pickerStyle(.segmented)
                            Spacer()
                        }
                        
                        Spacer().frame(height: 24)
                        
                        if viewModel.segment == 1 {
                            RecipeIngredientsListView(tint: viewModel.dominantColour)
                                .tint(viewModel.dominantColour)
                        } else if viewModel.segment == 2 {
                            RecipeStepsView(tint: viewModel.dominantColour)
                        }
                        
                    }
                    .padding(.horizontal)
                }
            }
            .fontDesign(.rounded)
        }
        .edgesIgnoringSafeArea(.top)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self, of: { geo in
            return geo.contentOffset.y + geo.contentInsets.top
        }, action: { new, old in
            viewModel.scrollOffset = new
        })
        .scrollClipDisabled(true)
        .ignoresSafeArea(.all, edges: .all.subtracting(.bottom))
        .environment(viewModel)
        .colorScheme(.dark)
        .background(
            image()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(2)
                .blur(radius: scheme == .dark ? 100 : 64)
                .ignoresSafeArea()
                .overlay(Material.ultraThin.opacity(0.2))
        )
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.recipe.title)
                    .font(.headline)
                    .opacity(viewModel.showNavTitle ? 1 : 0)
                    .accessibilityHidden(!viewModel.showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showNavTitle)
            }
        }
        .onChange(of: self.viewModel.recipe, initial: true) { _, newValue in
            if let domC = newValue.dominantColorHex {
                viewModel.dominantColour = Color(hex: domC) ?? .clear
            }
        }
        .task(id: "emojis") {
            try? await viewModel.generateEmojis()
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        AsyncImage(url: URL(string: viewModel.recipe.image.imageUrl ?? "")) { img in
            img
                .resizable()
                .aspectRatio(contentMode: .fill)
                .task {
                    if viewModel.recipe.dominantColorHex == nil, let dom = await img.getDominantColor() {
                        await viewModel.setDominantColour(to: dom)
                    }
                }
        } placeholder: {
            if let data = viewModel.recipe.image.imageThumbnailData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().opacity(0.1)
            }
        }
    }
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()

    let recipe = Recipe(
        id: UUID(),
        title: "Preview Carbonara",
        description: "Creamy pasta with crispy pancetta and pecorino.",
        author: "Preview Chef",
        sourceUrl: "https://example.com/carbonara",
        image: .init(imageThumbnailData: nil, imageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRBkWsRz51M9raJnOGEgsEbm0BNjhE18acBLA&s"),
        timing: .init(totalTime: 30, prepTime: 10, cookTime: 20),
        serves: "4",
        ratingInfo: .init(overallRating: 4.8, summarisedRating: "Rich and comforting", ratings: []),
        dateAdded: .now,
        dateModified: .now,
        ingredientSections: [
            .init(
                id: UUID(),
                title: "Main Ingredients",
                sortIndex: 0,
                ingredients: [
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                ]
            )
        ],
        stepSections: [
            .init(
                id: UUID(),
                sortIndex: 0,
                title: "Steps",
                steps: [
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [])
                ]
            )
        ],
        dominantColorHex: nil,
        homeId: nil
    )

    return NavigationStack {
        RecipePage(recipe)
    }
    .environment(AppRouter(initialTab: .recipes))
    .environment(RecipeTimerStore.shared)
}
