//
//  RecipeStepWithTimingsView.swift
//  Recipe
//
//  Created by Tom Knighton on 18/04/2026.
//

import Environment
import Models
import SwiftUI
import Design

struct RecipeStepWithTimingsView: View {
    @Environment(RecipeTimerStore.self) private var timers
    let step: RecipeStep
    let recipeId: UUID
    let matchedTimings: [MatchedTiming]
    let tint: Color
    @State private var buttonRects: [MatchedTiming: CGRect] = [:]
    let onTimerTap: (UUID) -> Void
    
    init(_ step: RecipeStep, recipeId: UUID, tint: Color, onTimerTap: @escaping (UUID) -> Void) {
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
                    let timer = timers.timers.first(where: { $0.metadata.stepTimingId == timing.timingId })
                    Button(action: {
                        if timer == nil {
                            print("Tapping timer index \(index)")
                            onTimerTap(timing.timingId)
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
