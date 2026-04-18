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
    public let completedIngredientIDs: Set<UUID>
    public let showMealplanShoppingTicks: Bool
    
    public init(
        tint: Color,
        completedIngredientIDs: Set<UUID> = [],
        showMealplanShoppingTicks: Bool = false
    ) {
        self.tint = tint
        self.completedIngredientIDs = completedIngredientIDs
        self.showMealplanShoppingTicks = showMealplanShoppingTicks
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
                            ingredientsView(for: step)
                            RecipeStepWithTimingsView(step, recipeId: vm.recipe.id, tint: tint) { id in
                                Task {
                                    await createAlarm(for: step, timingId: id)
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
                updateStepSections()
            }
        }
        .onChange(of: vm.recipe.stepSections) { _, _ in
            updateStepSections()
        }

    }

    private func updateStepSections() {
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
    
    private func createAlarm(for recipeStep: RecipeStep, timingId: UUID) async {
        let timings = recipeStep.timings
        guard let timer = timings.first(where: { $0.id == timingId }) else { return }
        
        print("Staarting timer \(timer.timeText) - \(timer.timeInSeconds)  - \(timings.count)")
        let _ = try? await RecipeTimerStore.shared.scheduleRecipeStepTimer(for: vm.recipe.id, recipeStepId: recipeStep.id, timingId: timingId, seconds: Int(timer.timeInSeconds), title: "Timer", description: recipeStep.instructionText)
    }
    
    @ViewBuilder
    private func ingredientInStep(for ingredient: RecipeIngredient) -> some View {
        // TODO: Toggle to enable in settings
        let showCompletionTick = false && showMealplanShoppingTicks && completedIngredientIDs.contains(ingredient.id)
        HStack(spacing: 2) {
            if showCompletionTick {
                Image(systemName: "checkmark")
            } else if let emoji = ingredient.emoji {
                Text(emoji)
            }
            
            Spacer().frame(width: 4)
            
            if let quantityText = ShoppingImportIngredientFormatter.scaledQuantityText(
                for: ingredient,
                scale: vm.recipe.ingredientScale,
                unitSystem: vm.recipe.ingredientUnitSystem
            ) {
                Text(quantityText)
                
                if let unit = ShoppingImportIngredientFormatter.scaledUnitText(
                    for: ingredient,
                    scale: vm.recipe.ingredientScale,
                    unitSystem: vm.recipe.ingredientUnitSystem
                ) {
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

extension RecipeStepsView {
    
    @ViewBuilder
    private func ingredientsView(for step: RecipeStep) -> some View {
        let allIngredients = vm.recipe.ingredientSections.flatMap { $0.ingredients }
        let ingredientsForStep = step.linkedIngredients.compactMap { id in
            allIngredients.first(where: { $0.id == id })
        }
        if ingredientsForStep.isEmpty == false {
            HorizontalScrollWithGradient {
                ForEach(ingredientsForStep) { ingredient in
                    ingredientInStep(for: ingredient)
                }
            }
        }
    }
}

