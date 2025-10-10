//
//  StepTimingMapTests.swift
//  Design
//
//  Created by Tom Knighton on 26/09/2025.
//

import Testing
import API
@testable import Design

@Test func TestTimingMap_SingleMinuteTimer() throws {
    
    // Arrange
    let step = RecipeStep(rawStep: "Start by adding the onion & carrots into a deep non-stick frying pan along with the coconut oil. Gently fry on a medium/ low heat for around 5 minutes. Season with salt.", sortIndex: 0, timings: [.init(timeInSeconds: 3600, timeText: "5", timeUnitText: "minutes")], temperatures: [])
    
    // Act
    let matchedTimings = step.matchedTimings()
    
    // Assert
    #expect(matchedTimings.count == 1)
    #expect(matchedTimings.first?.displayText == "5 minutes")
    #expect(matchedTimings.first?.seconds == 3600)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.first!.range.lowerBound) == 141)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.first!.range.upperBound) == 150)
}

@Test func TestTimingsMap_WithLongWhitespace() throws {
    // Arrange
    let step = RecipeStep(rawStep: "Start by adding the onion & carrots into a deep non-stick frying pan along with the coconut oil. Gently fry on a medium/ low heat for around 5      minutes. Season with salt.", sortIndex: 0, timings: [.init(timeInSeconds: 3600, timeText: "5", timeUnitText: "minutes")], temperatures: [])
    
    // Act
    let matchedTimings = step.matchedTimings()
    
    // Assert
    #expect(matchedTimings.count == 1)
    #expect(matchedTimings.first?.displayText == "5      minutes")
    #expect(matchedTimings.first?.seconds == 3600)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.first!.range.lowerBound) == 141)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.first!.range.upperBound) == 155)
}

@Test func TestTimingsMap_MultipleInstance() throws {
    // Arrange
    let step = RecipeStep(rawStep: "Cook for 20minutes then another 20    minutes then 20 minutes.", sortIndex: 0, timings: [.init(timeInSeconds: 3600, timeText: "20", timeUnitText: "minutes"), .init(timeInSeconds: 3600, timeText: "20", timeUnitText: "minutes"), .init(timeInSeconds: 3600, timeText: "20", timeUnitText: "minutes")], temperatures: [])
    
    // Act
    let matchedTimings = step.matchedTimings()
    
    // Assert
    #expect(matchedTimings.count == 3)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.first!.range.lowerBound) == 9)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.first!.range.upperBound) == 18)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.last!.range.lowerBound) == 51)
    #expect(step.rawStep.distance(from: step.rawStep.startIndex, to: matchedTimings.last!.range.upperBound) == 61)

}
