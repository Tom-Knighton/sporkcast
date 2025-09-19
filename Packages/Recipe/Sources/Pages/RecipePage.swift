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
    
    @State private var selection: Int = 1
    @State private var dominantColor: Color = .clear
    
    @State private var viewModel = RecipeViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let recipe = viewModel.recipe {
                        RecipeHeadingView(recipe.imageUrl ?? "")
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
                            
                            RecipeSourceButton(recipe, with: dominantColor)
                            
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
                            }
                            
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                    }
                }
                .fontDesign(.rounded)
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
            if viewModel.recipe == nil {
                self.viewModel = await RecipeViewModel(for: "https://beatthebudget.com/recipe/chicken-katsu-curry/", with: client)
            }
        }
        .environment(viewModel)
        .colorScheme(.dark)
        .background(
            ZStack {
                if let recipe = viewModel.recipe {
                    AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .task {
                                self.dominantColor = await img.getDominantColor() ?? .clear
                            }
                    } placeholder: {
                        EmptyView()
                    }
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(2)
                    .blur(radius: scheme == .dark ? 100 : 64)
                    .ignoresSafeArea()
                    .overlay(Material.ultraThin.opacity(0.2))
                }
            }
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
                Text(viewModel.recipe?.title ?? "Recipe")
                    .font(.headline)
                    .opacity(showNavTitle ? 1 : 0)
                    .accessibilityHidden(!showNavTitle)
                    .animation(.easeInOut(duration: 0.2), value: showNavTitle)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipePage()
            .withPreviewEnvs()
    }
    
}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
