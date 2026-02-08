//
//  EditStepRow.swift
//  Recipe
//
//  Created by Tom Knighton on 16/01/2026.
//

import SwiftUI
import Models
import Design
import Observation
import UniformTypeIdentifiers
import UIKit
import Environment

struct StepRow: View {
    @Binding var step: RecipeStep
    let focusedStepID: FocusState<UUID?>.Binding
    let tint: Color
    let allIngredients: [RecipeIngredient]
    
    @State private var attributed: AttributedString = ""
    @State private var matchedIngredients: [RecipeIngredient] = []
    @State private var showIngredientSheet: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Text(attributed)
                    .opacity(0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: attributed) { _, newValue in
                        let v = String(newValue.characters)
                        step.instructionText = v
                        self.parseInstructionText(v)
                    }
                    .onChange(of: step, initial: true) { _, newValue in
                        attributed = RecipeStepHighlighter.highlight(
                            step: step,
                            font: .body,
                            tint: .primary
                        )
                    }
                    .overlay {
                        TextEditor(text: $attributed)
                            .padding(.horizontal, -4)
                            .padding(.vertical, -10)
                            .scrollDisabled(true)
                            .focused(focusedStepID, equals: step.id)
                    }
                
                Image(systemName: "line.3.horizontal")
            }
            
            HorizontalScrollWithGradient {
                ForEach(matchedIngredients) { ingredient in
                    ingredientInStep(for: ingredient)
                        .onTapGesture {
                            self.showIngredientSheet = true
                        }
                }
                
                Button(action: { self.showIngredientSheet = true }) {
                    Label("Link Ingredient", systemImage: "pencil")
                        .labelIconToTitleSpacing(6)
                        .transform { view in
                            if matchedIngredients.count == 0 {
                                view.labelStyle(.titleAndIcon)
                            } else {
                                view.labelStyle(.iconOnly)
                            }
                        }
                }
            }
        }
        .onChange(of: allIngredients, initial: true) { _, ingredients in
            let ingredientMatcher = IngredientStepMatcher()
            let autoMatched = ingredientMatcher.matchIngredients(for: step.instructionText, ingredients: ingredients)
            
            if !step.linkedIngredients.isEmpty {
                self.matchedIngredients = ingredients.filter { step.linkedIngredients.contains($0.id) }
            } else {
                self.matchedIngredients = autoMatched
            }
        }
        .sheet(isPresented: $showIngredientSheet) {
            EditLinkedIngredientsSheet(
                allIngredients: allIngredients,
                matchedIngredients: matchedIngredients,
                instructionText: step.instructionText,
                onUpdate: { updatedMatched in
                    self.matchedIngredients = updatedMatched
                    step.linkedIngredients = updatedMatched.map { $0.id }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

extension StepRow {
    
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
    
    private func parseInstructionText(_ text: String) {
        let attributed = try? parseInstruction(text, "en")
        self.step.instructionText = text
        if let attributed {
            if attributed.temperature != 0 {
                step.temperatures = [.init(id: UUID(), temperature: attributed.temperature, temperatureText: attributed.temperatureText, temperatureUnitText: attributed.temperatureUnitText)]
            }
            
            step.timings = attributed.timeItems.map { RecipeStepTiming(id: UUID(), timeInSeconds: Double($0.timeInSeconds), timeText: $0.timeText, timeUnitText: $0.timeUnitText )}
        }
    }
}
