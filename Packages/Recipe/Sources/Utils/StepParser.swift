import Models
import SwiftUI
import Foundation
import RegexBuilder
import Design

public struct RecipeStepHighlighter {
    
    public static func highlight(step: RecipeStep, font: Font = .body, tint: Color = .mint) -> AttributedString {
        var attr = AttributedString(step.instructionText)
        guard !step.instructionText.isEmpty else { return attr }
        
        func apply(_ r: Range<String.Index>) {
            guard let low = AttributedString.Index(r.lowerBound, within: attr),
                  let upp = AttributedString.Index(r.upperBound, within: attr),
                  low <= upp else { return }
            
            let bold = font.weight(.heavy)
            attr[low..<upp].font = bold
            attr[low..<upp].foregroundColor = tint.adjust(brightness: 0.5)
        }
        
        // MARK: - Timings (highlight ALL occurrences)
        
        for timing in step.timings {
            let timeText = timing.timeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let unitText = timing.timeUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !timeText.isEmpty else { continue }
            
            if unitText.isEmpty {
                let timeOnly = Regex { /(?i)\b/; timeText; /\b/ }
                for r in step.instructionText.ranges(of: timeOnly) { apply(r) }
                continue
            }
            
            let timingToken = Regex {
                /(?i)\b/
                timeText
                /\s*/
                ChoiceOf {
                    unitText
                    Regex { unitText; "s" }
                    Regex { unitText; "." }
                    Regex { unitText; "s." }
                }
                /\b/
            }
            
            for r in step.instructionText.ranges(of: timingToken) { apply(r) }
        }
        
        // MARK: - Temperatures (highlight ALL occurrences)
        
        for temperature in step.temperatures {
            let tempText = temperature.temperatureText.trimmingCharacters(in: .whitespacesAndNewlines)
            let unitText = temperature.temperatureUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tempText.isEmpty else { continue }
            
            if unitText.isEmpty {
                let tempOnly = Regex { /(?i)\b/; tempText; /\b/ }
                for r in step.instructionText.ranges(of: tempOnly) { apply(r) }
                continue
            }
            
            let tempToken = Regex {
                /(?i)\b/
                tempText
                /\s*/
                Optionally { "°" }
                /\s*/
                ChoiceOf {
                    unitText
                    Regex { unitText; "." }
                    Regex { unitText; "s" }
                    Regex { unitText; "s." }
                }
                /\b/
            }
            
            for r in step.instructionText.ranges(of: tempToken) { apply(r) }
        }
        
        return attr
    }
}

private extension String {
    func ranges<R: RegexComponent>(of regex: R) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchStart = startIndex
        
        while searchStart < endIndex,
              let r = self[searchStart...].firstRange(of: regex) {
            let absolute = r.lowerBound..<r.upperBound
            result.append(absolute)
            searchStart = absolute.upperBound
        }
        
        return result
    }
}
