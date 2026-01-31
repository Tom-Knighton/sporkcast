//
//  IngredientParser.swift
//  Recipe
//
//  Created by Tom Knighton on 18/09/2025.
//

import Models
import SwiftUI
import Foundation
import RegexBuilder
import Design

public struct IngredientHighlighter {
    
    static func highlight(ingredient: RecipeIngredient, font: Font = .body, tint: Color = .mint) -> AttributedString {
        
        var attr = AttributedString(ingredient.ingredientText)
        guard !ingredient.ingredientText.isEmpty, let quantityText = ingredient.quantity?.quantityText, !quantityText.isEmpty else { return attr }
        
        func apply(_ r: Range<String.Index>) {
            guard let low = AttributedString.Index(r.lowerBound, within: attr),
                  let upp = AttributedString.Index(r.upperBound, within: attr),
                  low <= upp else { return }
            
            let bold = font.weight(.heavy)
            attr[low..<upp].font = bold
            attr[low..<upp].foregroundColor = tint.adjust(brightness: 0.5)
        }
                
        let qtyRegex = Regex {
            /(?i)\b/
            quantityText
        }
        
        guard let qtyMatch = ingredient.ingredientText.firstRange(of: qtyRegex) else { return attr }
        apply(qtyMatch)
        
        if let unit = ingredient.unit?.unitText?.trimmingCharacters(in: .whitespacesAndNewlines), !unit.isEmpty {
            let unitRegex = Regex {
                /(?i)/
                ChoiceOf {
                    unit
                    Regex { unit; "s" }
                }
                /\b/
            }
            
            let candidates = ingredient.ingredientText.ranges(of: unitRegex)
            let picked = candidates.first(where: { $0.lowerBound >= qtyMatch.upperBound}) ?? candidates.first
            if let p = picked { apply(p) }
        }
        
        
        return attr
    }
}

private extension String {
    // Convenience: collect all non-overlapping ranges that match a regex
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


extension Color {
    func adjust(hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, opacity: CGFloat = 1) -> Color {
        let color = UIColor(self)
        var currentHue: CGFloat = 0
        var currentSaturation: CGFloat = 0
        var currentBrigthness: CGFloat = 0
        var currentOpacity: CGFloat = 0
        
        if color.getHue(&currentHue, saturation: &currentSaturation, brightness: &currentBrigthness, alpha: &currentOpacity) {
            return Color(hue: currentHue + hue, saturation: currentSaturation + saturation, brightness: currentBrigthness + brightness, opacity: currentOpacity + opacity)
        }
        return self
    }
}
