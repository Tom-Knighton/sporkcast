//
//  RecipePage.swift
//  Recipe
//
//  Created by Tom Knighton on 24/08/2025.
//

import SwiftUI
import Design
import API
import SwiftData

public struct RecipePage: View {
    
    @State private var offset: CGFloat = 0
    @State private var showNavTitle = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.networkClient) private var client
    @Environment(\.modelContext) private var context
    @State private var selection: Int = 2
    @State private var dominantColor: Color = .clear
    @State private var viewModel = RecipeViewModel()
    let recipeId: UUID?
    
    public init() {
        recipeId = nil
    }
    
    public init(_ recipe: Recipe) {
        self.recipeId = nil
        self.viewModel.recipe = recipe
        self.dominantColor = Color(hex: recipe.dominantColorHex ?? "") ?? .clear
    }
    
    public init(recipeId: UUID) {
        self.recipeId = recipeId
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let recipe = viewModel.recipe {
                        RecipeHeadingView {
                            image()
                                .mask(Rectangle().ignoresSafeArea(edges: .top))
                        }
                        .stretchy()
                        .ignoresSafeArea()
                        
                        RecipeTitleView(for: recipe, showNavTitle: $showNavTitle)
                        
                        VStack {

                            Spacer().frame(height: 20)
                            
                            HStack(spacing: 24) {
                                if let totalTime = recipe.totalMins {
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
                                
                                if let cookingMins = recipe.minutesToCook {
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
                                
                                if let serves = recipe.serves {
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
                            
                            RecipeSourceButton(recipe, with: dominantColor) {
                                image()
                            }
                            
                            Spacer().frame(height: 20)
                            HStack {
                                Picker("", selection: $selection) {
                                    Text("Ingredients")
                                        .tag(1)
                                    Text("Directions").tag(2)
                                }
                                .pickerStyle(.segmented)
                                Spacer()
                            }
                            
                            Spacer().frame(height: 24)
                            
                            if selection == 1 {
                                RecipeIngredientsListView(tint: dominantColor)
                                    .tint(dominantColor)
                            } else if selection == 2 {
                                RecipeStepsView(tint: dominantColor)
                            }
                            
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                    }
                }
                .fontDesign(.rounded)
            }
            .edgesIgnoringSafeArea(.top)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self, of: { geo in
                return geo.contentOffset.y + geo.contentInsets.top
            }, action: { new, old in
                offset = new
            })
        }
        .scrollClipDisabled(true)
        .ignoresSafeArea(.all, edges: .all.subtracting(.bottom))
        .task(id: "load") {
            if let recipeId {
                self.viewModel = await RecipeViewModel(with: recipeId, context: context)
            } else if viewModel.recipe == nil {
                self.viewModel = await RecipeViewModel(for: "https://beatthebudget.com/recipe/chicken-katsu-curry/", with: client)
            } else if let r = viewModel.recipe {
                self.viewModel = RecipeViewModel(for: r, context: context)
            }
        }
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
                Text(viewModel.recipe?.title ?? "Recipe")
                    .font(.headline)
                    .opacity(showNavTitle ? 1 : 0)
                    .accessibilityHidden(!showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: showNavTitle)
            }
        }
        .onChange(of: self.viewModel.recipe, initial: true) { _, newValue in
            if let domC = newValue?.dominantColorHex {
                self.dominantColor = Color(hex: domC) ?? .clear
            }
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        if let recipe = viewModel.recipe {
            AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { img in
                img
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .task {
                        if viewModel.recipe?.dominantColorHex == nil, let dom = await img.getDominantColor() {
                            setDominantColour(to: dom)
                        }
                    }
            } placeholder: {
                if let data = recipe.thumbnailData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let file = recipe.imageAssetFileName,
                          let url = try? ImageStore.imagesDirectory().appendingPathComponent(file),
                          let data = try? Data(contentsOf: url),
                          let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().opacity(0.1)
                }
            }
            
            
        } else {
            Rectangle().opacity(0.1)
        }
    }
    
    private func setDominantColour(to colour: Color) {
        self.dominantColor = colour
        
        if let hex = colour.toHex() {
            self.viewModel.recipe?.dominantColorHex = hex
            try? context.save()
        }
    }
}

#Preview {
    NavigationStack {
        RecipePage()
            .withPreviewEnvs()
    }
    
}
