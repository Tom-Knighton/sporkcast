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
import NukeUI

public struct RecipePage: View {
    
    @Environment(AppRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Environment(\.networkClient) private var client
    @Environment(\.displayScale) private var displayScale

    @State private var viewModel: RecipeViewModel
    @State private var allowDismissalGesture: AllowedNavigationDismissalGestures = .none
    @State private var commentsSnapshot: UIImage?

    public init(_ recipe: Recipe) {
        self.viewModel = .init(recipe: recipe)
        self.viewModel.dominantColour = Color(hex: recipe.dominantColorHex ?? "") ?? .clear
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
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
                                
                                if let commentsUIImage = commentsSnapshot {
                                    Image(uiImage: commentsUIImage)
                                        .tag(3)
                                } else {
                                    Text("Comments")
                                        .tag(3)
                                }
                            }
                            .pickerStyle(.segmented)
                            Spacer()
                        }
                        
                        Spacer().frame(height: 24)
                        
                        switch viewModel.segment {
                        case 1:
                            RecipeIngredientsListView(tint: viewModel.dominantColour)
                                .tint(viewModel.dominantColour)
                        case 2:
                            RecipeStepsView(tint: viewModel.dominantColour)
                        case 3:
                            RecipeCommentsView()
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
            }
            .scrollClipDisabled(true)
            .fontDesign(.rounded)
            .tabBarMinimizeBehavior(.onScrollDown)
            .scrollBounceBehavior(.always, axes: .vertical)
            .coordinateSpace(name: "recipeScroll")
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { newValue, _ in
                viewModel.scrollOffset = newValue
            }
        }
        .navigationAllowDismissalGestures(allowDismissalGesture)
        .task {
            Task {
                try? await Task.sleep(for: .seconds(1))
                allowDismissalGesture = .all
            }
        }
        .edgesIgnoringSafeArea(.top)
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
            if viewModel.showNavTitle {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.recipe.title)
                        .font(.headline)
                        .transition(.opacity)
                        .accessibilityHidden(!viewModel.showNavTitle)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showNavTitle)
                }
            }
        }
        .onChange(of: self.viewModel.recipe, initial: true) { _, newValue in
            if let domC = newValue.dominantColorHex {
                viewModel.dominantColour = Color(hex: domC) ?? .clear
            }
        }
        .task(id: "emojis") {
            try? await viewModel.generateEmojis()
            try? await viewModel.generateTipsAndSummary()
        }
        .task(id: viewModel.recipe.summarisedTip) {
            generateCommentsLabel()
        }
        .sensoryFeedback(.success, trigger: viewModel.recipe.summarisedTip)
        .toolbar {
            Button(action: { router.presentSheet(.recipeEdit(recipe: viewModel.recipe))}) {
                Image(systemName: "pencil")
            }
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        LazyImage(url: URL(string: viewModel.recipe.image.imageUrl ?? "")) { state in
            if let img = state.image {
                img
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .task {
                        if viewModel.recipe.dominantColorHex == nil, let dom = await img.getDominantColor() {
                            await viewModel.setDominantColour(to: dom)
                        }
                    }
            } else {
                Rectangle().opacity(0.1)
            }
        }
    }
}

extension RecipePage {
    @ViewBuilder
    private func buildPickerLabel(title: String, systemImage: String? = nil) -> some View {
        Label(title, systemImage: systemImage ?? "")
            .font(.footnote)
            .labelIconToTitleSpacing(2)
    }
    
    func generateCommentsLabel() {
        Task {
            let renderer = ImageRenderer(
                content: buildPickerLabel(title: "Comments", systemImage: viewModel.recipe.summarisedTip == nil ? "" : "sparkles"), scale: self.displayScale)
            if let image = renderer.uiImage {
                self.commentsSnapshot = image
            }
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension ImageRenderer {
    
    @MainActor
    convenience init(content: Content, scale: CGFloat) {
        self.init(content: content)
        self.scale = scale
    }
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()

    let recipe = Recipe(
        id: UUID(),
        title: "Preview Carbonara",
        description: "Creamy pasta with crispy pancetta and pecorino.",
        summarisedTip: "Users tend to recommend adding less salt than recommended - but comment that you may need to add spices to taste as it's a bit bland. Overall positive reviews.",
        author: "Preview Chef",
        sourceUrl: "https://example.com/carbonara",
        image: .init(imageThumbnailData: nil, imageUrl: "https://ichef.bbci.co.uk/food/ic/food_16x9_1600/recipes/sausage_and_mash_pie_94920_16x9.jpg"),
        timing: .init(totalTime: 30, prepTime: 10, cookTime: 20),
        serves: "4",
        ratingInfo: .init(overallRating: 4.5, totalRatings: 3, summarisedRating: "Rich and comforting", ratings: [
            .init(id: UUID(), rating: 5, comment: "A bit salty but overall very nice!"),
            .init(id: UUID(), rating: 5, comment: "The perfect authentic carbonarra"),
            .init(id: UUID(), rating: 1, comment: "Missing too many ingredients!"),
        ]),
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
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: []),
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: []),
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
