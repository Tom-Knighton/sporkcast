//
//  EditStepRow.swift
//  Recipe
//
//  Created by Tom Knighton on 16/01/2026.
//

import SwiftUI
import Models
import Design

struct StepRow: View {
    @Binding var step: RecipeStep
    let focusedStepID: FocusState<UUID?>.Binding
    let tint: Color
    
    @State private var attributed: AttributedString = ""
    
    var body: some View {
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
