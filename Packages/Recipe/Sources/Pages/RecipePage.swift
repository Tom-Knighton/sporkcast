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

public struct RecipePage: View {
    
    @State private var offset: CGFloat = 0
    @State private var showNavTitle = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.networkClient) private var client
    @Environment(\.modelContext) private var context
    @State private var selection: Int = 2
    @State private var dominantColor: Color = .clear
    
    @State private var viewModel: RecipeViewModel
    
    public init(_ recipe: Recipe) {
        self.viewModel = .init(recipe: recipe)
        self.dominantColor = Color(hex: recipe.dominantColorHex ?? "") ?? .clear
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
                    
                    RecipeTitleView(showNavTitle: $showNavTitle)
                    
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
                        
                        RecipeSourceButton(with: dominantColor) {
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
                    .opacity(showNavTitle ? 1 : 0)
                    .accessibilityHidden(!showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: showNavTitle)
            }
        }
        .onChange(of: self.viewModel.recipe, initial: true) { _, newValue in
            if let domC = newValue.dominantColorHex {
                self.dominantColor = Color(hex: domC) ?? .clear
            }
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
                    setDominantColour(to: dom)
                }
            }
    } placeholder: {
        if let data = viewModel.recipe.image.imageThumbnailData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let file = viewModel.recipe.image.imageAssetFileName,
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
}

private func setDominantColour(to colour: Color) {
    self.dominantColor = colour
    
    if let hex = colour.toHex() {
        self.viewModel.recipe.dominantColorHex = hex
        try? context.save()
    }
}
}

#Preview {
    AsyncModel { asyncVal in
        NavigationStack {
            RecipePage(asyncVal)
                .withPreviewEnvs()
        }
    } model: {
        await SDRecipe(from: RecipeDTOMockBuilder().build()).toDomainModel()
    }
    
    
}

struct AsyncModel<VisualContent: View, ModelData>: View {
    // Standard view builder, accepting async-fetched data as a parameter
    var viewBuilder: (ModelData) -> VisualContent
    // data fetcher. Notice it can throw as well
    var model: () async throws -> ModelData?
    
    @State private var modelData: ModelData?
    @State private var error: Error?
    
    var body: some View {
        safeView
            .task {
                do {
                    self.modelData = try await model()
                } catch {
                    self.error = error
                    // print detailed error info to console
                    print(error)
                }
            }
    }
    
    @ViewBuilder
    private var safeView: some View {
        if let modelData {
            viewBuilder(modelData)
        }
        // in case of error, its description rendered
        // right on preview to make troubleshooting faster
        else if let error {
            Text(error.localizedDescription)
                .foregroundStyle(Color.red)
        }
        // a stub for awaiting.
        // Actually, we should return some non-empty view from here
        // to make sure .task { } is triggered
        else {
            Text("Calculating async data...")
        }
    }
}
