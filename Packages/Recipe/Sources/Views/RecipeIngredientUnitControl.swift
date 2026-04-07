//
//  RecipeIngredientUnitControl.swift
//  Recipe
//
//  Created by Tom Knighton on 07/04/2026.
//

import SwiftUI
import Models

public struct RecipeIngredientUnitControl: View {
    public let selectedUnitSystem: RecipeIngredientUnitSystem
    public let tint: Color
    public let onUnitSystemChange: (RecipeIngredientUnitSystem) -> Void
    public let onReset: () -> Void
    public let onClose: () -> Void

    @State private var draftUnitSystem: RecipeIngredientUnitSystem

    public init(
        selectedUnitSystem: RecipeIngredientUnitSystem,
        tint: Color = .mint,
        onUnitSystemChange: @escaping (RecipeIngredientUnitSystem) -> Void,
        onReset: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.selectedUnitSystem = selectedUnitSystem
        self.tint = tint
        self.onUnitSystemChange = onUnitSystemChange
        self.onReset = onReset
        self.onClose = onClose
        self._draftUnitSystem = State(initialValue: selectedUnitSystem)
    }

    public var body: some View {
        container
            .onChange(of: draftUnitSystem) { _, newValue in
                onUnitSystemChange(newValue)
            }
            .onChange(of: selectedUnitSystem) { _, newValue in
                guard newValue != draftUnitSystem else { return }
                draftUnitSystem = newValue
            }
    }
}

private extension RecipeIngredientUnitControl {
    @ViewBuilder
    var container: some View {
        GlassEffectContainer(spacing: 0) {
            content
                .padding(14)
                .glassEffect(
                    .regular.tint(tint.opacity(0.2)).interactive(),
                    in: .rect(cornerRadius: 16)
                )
        }
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Ingredient Units", systemImage: "scalemass")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(draftUnitSystem.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }

            Picker("Unit System", selection: $draftUnitSystem) {
                Text(RecipeIngredientUnitSystem.original.displayName)
                    .tag(RecipeIngredientUnitSystem.original)
                Text(RecipeIngredientUnitSystem.metric.displayName)
                    .tag(RecipeIngredientUnitSystem.metric)
                Text(RecipeIngredientUnitSystem.imperial.displayName)
                    .tag(RecipeIngredientUnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Ingredient unit system")

            HStack(spacing: 10) {
                if draftUnitSystem != .original {
                    resetButton
                }

                Spacer()
                doneButton
            }
        }
    }

    @ViewBuilder
    var resetButton: some View {
        Button("Reset to Original", action: onReset)
            .buttonStyle(.glass)
    }

    @ViewBuilder
    var doneButton: some View {
        Button("Done", action: onClose)
            .buttonStyle(.glassProminent)
    }
}
