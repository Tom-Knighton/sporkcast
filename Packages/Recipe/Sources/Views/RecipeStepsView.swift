//
//  RecipeStepsView.swift
//  Recipe
//
//  Created by Tom Knighton on 21/09/2025.
//

import SwiftUI
import API
import Design

public struct RecipeStepsView: View {
    
    @Environment(RecipeViewModel.self) private var viewModel
    @State private var stepSections: [RecipeStepSection] = []
    @State private var stepIngredientMap: [String: [RecipeIngredient]] = [:]
    
    public let tint: Color
    
    public init(tint: Color) {
        self.tint = tint
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(stepSections) { section in
                Text(section.title)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(section.steps ?? []) { step in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(tint)
                                .frame(width: 25, height: 25)
                            
                            Text(String(describing: step.sortIndex + 1))
                                .bold()
                        }
                        
                        VStack {
                            let ingredientsForStep = stepIngredientMap[step.rawStep] ?? []
                            if ingredientsForStep.isEmpty == false {
                                HorizontalScrollWithGradient {
                                    ForEach(stepIngredientMap[step.rawStep] ?? []) { ingredient in
                                        HStack {
                                            if let emoji = ingredient.emojiDescriptor {
                                                Text(emoji)
                                            }
                                            Text(ingredient.ingredient ?? ingredient.rawIngredient)
                                        }
                                        .font(.footnote.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Material.thin)
                                        .clipShape(.capsule)
                                        
                                    }
                                }
                            }
                            
                            
                            Text(step.rawStep)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Material.thin)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity)
        .onAppear {
            if stepSections.isEmpty {
                let sections = viewModel.recipe?.stepSections?.sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
                sections.forEach { sect in
                    if sect.title.isEmpty {
                        sect.title = "Steps:"
                    }
                    sect.steps = sect.steps?.sorted(by: { $0.sortIndex < $1.sortIndex })
                    
                    let ingredientMatcher = IngredientStepMatcher()
                    sect.steps?.forEach { step in
                        let ingredients = ingredientMatcher.matchIngredients(for: step, ingredients: viewModel.recipe?.ingredients ?? [])
                        self.stepIngredientMap[step.rawStep] = ingredients
                    }
                }
                self.stepSections = sections
            }
        }
    }
}


struct HorizontalScrollWithGradient<Content: View>: View {
    struct Metrics: Equatable {
        var offsetX: CGFloat
        var contentWidth: CGFloat
        var containerWidth: CGFloat
    }
    
    let content: Content
    @State private var metrics = Metrics(offsetX: 0, contentWidth: 0, containerWidth: 0)
    @State private var hasMoreToScroll = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
        .onScrollGeometryChange(for: Metrics.self) { g in
            Metrics(
                offsetX: max(0, g.contentOffset.x),
                contentWidth: g.contentSize.width,
                containerWidth: g.containerSize.width
            )
        } action: { newMetrics, _ in
            metrics = newMetrics
            let endVisibleX = metrics.offsetX + metrics.containerWidth
            withAnimation {
                self.hasMoreToScroll = metrics.contentWidth > metrics.containerWidth && endVisibleX < metrics.contentWidth - 1
            }
        }
        .mask(LinearGradient(gradient: Gradient(colors: [.black, .black, .black, hasMoreToScroll ? .clear : .black]), startPoint: .leading, endPoint: .trailing))
    }
}
