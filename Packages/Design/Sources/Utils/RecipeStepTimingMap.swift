//
//  RecipeStepTimingMap.swift
//  Design
//
//  Created by Tom Knighton on 26/09/2025.
//

import Foundation
import RegexBuilder
import API

public struct MatchedTiming: Equatable, Hashable {
    public let range: Range<String.Index>
    public let seconds: Double
    public let displayText: String
    
    public init(range: Range<String.Index>, seconds: Double, displayText: String) {
        self.range = range
        self.seconds = seconds
        self.displayText = displayText
    }
}

public extension RecipeStep {
    
    func matchedTimings() -> [MatchedTiming] {
        
        guard !rawStep.isEmpty, let timings, !timings.isEmpty else { return [] }
        
        struct Key: Hashable { let timeText: String; let unit: String }
        
        func makeRegex(for key: Key) -> some RegexComponent {
            Regex {
                Anchor.wordBoundary
                Regex<String>(verbatim: key.timeText)
                ZeroOrMore(.whitespace)
                Regex<String>(verbatim: key.unit)
                Anchor.wordBoundary
            }
            .ignoresCase()
        }
        
        var pools: [Key: [Range<String.Index>]] = [:]
        
        for t in timings {
            let key = Key(timeText: t.timeText, unit: t.timeUnitText)
            if pools[key] != nil { continue }
            
            let regex = makeRegex(for: key)
            var ranges: [Range<String.Index>] = []
            for match in rawStep.matches(of: regex) {
                ranges.append(match.range)
            }
            
            pools[key] = ranges
        }
        
        var assigned: [(range: Range<String.Index>, seconds: Double)] = []
        
        for t in timings {
            let key = Key(timeText: t.timeText, unit: t.timeUnitText)
            guard var pool = pools[key], !pool.isEmpty else { continue }
            let r = pool.removeFirst()
            pools[key] = pool
            assigned.append((range: r, seconds: t.timeInSeconds))
        }
        
        assigned.sort { a, b in a.range.lowerBound < b.range.lowerBound }
        
        return assigned.map { item in
            MatchedTiming(range: item.range, seconds: item.seconds, displayText: String(rawStep[item.range]))
        }
    }
}
