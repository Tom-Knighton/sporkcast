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
                            
                            
                            RecipeStepWithTimingsView(step, tint: tint)

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

struct RecipeStepWithTimingsView: View {
    let step: RecipeStep
    let matchedTimings: [MatchedTiming]
    let tint: Color
    @State private var buttonRects: [MatchedTiming: CGRect] = [:]
    
    init(_ step: RecipeStep, tint: Color) {
        self.step = step
        self.tint = tint
        self.matchedTimings = step.matchedTimings().sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    var body: some View {
        FlowLayout(alignment: .leading, spacing: 4) {
            ForEach(Array(createSegments().enumerated()), id: \.offset) { index, segment in
                switch segment {
                case .text(let string):
                    ForEach(string.components(separatedBy: " "), id: \.self) { word in
                        if !word.isEmpty {
                            Text(word)
                                .baselineOffset(-4)
                                .fixedSize()
                        }
                    }
                case .button(let timing):
                    Button(action: {
                        
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                            Text(timing.displayText)
                        }
                        .bold()
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .clipShape(.capsule)
                        .fixedSize()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private enum TextSegment {
        case text(String)
        case button(MatchedTiming)
    }
    
    private func createSegments() -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = step.rawStep.startIndex
        
        for timing in matchedTimings {
            if currentIndex < timing.range.lowerBound {
                let textBefore = String(step.rawStep[currentIndex..<timing.range.lowerBound])
                if !textBefore.isEmpty {
                    segments.append(.text(textBefore))
                }
            }
            
            segments.append(.button(timing))
            
            currentIndex = timing.range.upperBound
        }
        
        if currentIndex < step.rawStep.endIndex {
            let remainingText = String(step.rawStep[currentIndex..<step.rawStep.endIndex])
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }
        
        return segments
    }
}

