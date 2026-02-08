//
//  RecipeStepsView.swift
//  Recipe
//
//  Created by Tom Knighton on 21/09/2025.
//

import SwiftUI
import Models
import Design
import Environment
import AlarmKit

@MainActor
public struct RecipeStepsView: View {
    
    @Environment(RecipeViewModel.self) private var vm
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
                ForEach(section.steps.sorted(by: { $0.sortIndex < $1.sortIndex })) { step in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(tint)
                                .frame(width: 25, height: 25)
                            
                            Text(String(describing: step.sortIndex + 1))
                                .bold()
                        }
                        
                        VStack {
                            let ingredientsForStep = vm.recipe.ingredientSections.flatMap { $0.ingredients }.filter { step.linkedIngredients.contains($0.id) }
                            if ingredientsForStep.isEmpty == false {
                                HorizontalScrollWithGradient {
                                    ForEach(ingredientsForStep) { ingredient in
                                        ingredientInStep(for: ingredient)
                                    }
                                }
                            }
                            RecipeStepWithTimingsView(step, recipeId: vm.recipe.id, tint: tint) { index in
                                Task {
                                    await createAlarm(for: step, timerIndex: index)
                                }
                            }
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
            
            Spacer().frame(height: 8)
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity)
        .onAppear {
            if stepSections.isEmpty {
                let sections = vm.recipe.stepSections
                    .sorted(by: { $0.sortIndex < $1.sortIndex })
                    .compactMap { sect in
                        var newSect = sect
                        if newSect.title.isEmpty {
                            newSect.title = "Steps:"
                        }
                        newSect.steps = newSect.steps.sorted(by: { $0.sortIndex < $1.sortIndex })
                        return newSect
                    }
                self.stepSections = sections
            }
        }

    }

    private func createAlarm(for recipeStep: RecipeStep, timerIndex: Int) async {
        let timings = recipeStep.timings
        guard timerIndex < timings.count else { return }
        let timer = timings[timerIndex]
        
        let _ = try? await RecipeTimerStore.shared.scheduleRecipeStepTimer(for: vm.recipe.id, recipeStepId: recipeStep.id, timerIndex: timerIndex, seconds: Int(timer.timeInSeconds), title: "Timer", description: recipeStep.instructionText)
    }
    
    @ViewBuilder
    private func ingredientInStep(for ingredient: RecipeIngredient) -> some View {
        HStack(spacing: 2) {
            if let emoji = ingredient.emoji {
                Text(emoji)
            }
            
            Spacer().frame(width: 4)
            
            if let quantityText = ingredient.quantity?.quantityText {
                Text(quantityText)
                
                if let unit = ingredient.unit?.unitText {
                    Text(unit)
                }
            }
            
            Text(ingredient.ingredientPart ?? ingredient.ingredientText)
        }
        .font(.footnote.bold())
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Material.thin)
        .clipShape(.capsule)
        
    }
}

struct RecipeStepWithTimingsView: View {
    @Environment(RecipeTimerStore.self) private var timers
    let step: RecipeStep
    let recipeId: UUID
    let matchedTimings: [MatchedTiming]
    let tint: Color
    @State private var buttonRects: [MatchedTiming: CGRect] = [:]
    let onTimerTap: (Int) -> Void
    
    init(_ step: RecipeStep, recipeId: UUID, tint: Color, onTimerTap: @escaping (Int) -> Void) {
        self.step = step
        self.tint = tint
        self.recipeId = recipeId
        self.matchedTimings = step.matchedTimings().sorted { $0.range.lowerBound < $1.range.lowerBound }
        self.onTimerTap = onTimerTap
    }

    var body: some View {
        FlowLayout(alignment: .leading, spacing: 4) {
            ForEach(Array(createSegments().enumerated()), id: \.offset) { index, segment in
                switch segment {
                case .text(let string):
                    ForEach(string.components(separatedBy: " ").enumerated(), id: \.offset) { index, word in
                        if !word.isEmpty {
                            Text(word)
                                .baselineOffset(-4)
                                .fixedSize()
                        }
                    }
                case .button(let timing):
                    let index = step.matchedTimings().firstIndex(where: { $0.range == timing.range }) ?? 0
                    let timer = timers.timers.first(where: { $0.metadata.recipeId == recipeId && $0.metadata.recipeStepId == step.id && $0.metadata.stepTimerIndex == index })
                    Button(action: {
                        if timer == nil {
                            onTimerTap(index)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                            
                            if let timer {
                                if case let .countdown(total, elapsed, startDate) = timer.presentation.mode {
                                    let remaining = max(0, total - elapsed)
                                    Text(timerInterval: startDate ... startDate.addingTimeInterval(remaining),
                                         countsDown: true,
                                         showsHours: true)
                                }
                                if case let .paused(total, prev) = timer.presentation.mode {
                                    let remaining = max(0, total - prev)
                                    let duration = Duration.seconds(remaining)
                                    Text(duration, format: .time(pattern: remaining >= 3600 ? .hourMinuteSecond : .minuteSecond))
                                }
                                
                            } else {
                                Text(timing.displayText)
                            }
                        }
                        .fontWeight(.heavy)
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
        var currentIndex = step.instructionText.startIndex
        
        for timing in matchedTimings {
            if currentIndex < timing.range.lowerBound {
                let textBefore = String(step.instructionText[currentIndex..<timing.range.lowerBound])
                if !textBefore.isEmpty {
                    segments.append(.text(textBefore))
                }
            }
            
            segments.append(.button(timing))
            
            currentIndex = timing.range.upperBound
        }
        
        if currentIndex < step.instructionText.endIndex {
            let remainingText = String(step.instructionText[currentIndex..<step.instructionText.endIndex])
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }
        
        return segments
    }
}

