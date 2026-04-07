//
//  RecipeIngredientScaleControl.swift
//  Recipe
//
//  Created by Tom Knighton on 07/04/2026.
//

import SwiftUI

public struct RecipeIngredientScaleControl: View {
    public let scale: Double
    public let tint: Color
    public let onScaleChange: (Double) -> Void
    public let onReset: () -> Void
    public let onClose: () -> Void

    @State private var sliderValue: Double

    public init(
        scale: Double,
        tint: Color = .mint,
        onScaleChange: @escaping (Double) -> Void,
        onReset: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.scale = scale
        self.tint = tint
        self.onScaleChange = onScaleChange
        self.onReset = onReset
        self.onClose = onClose
        self._sliderValue = State(initialValue: scale)
    }

    public var body: some View {
        container
            .onChange(of: sliderValue) { _, newValue in
                onScaleChange(newValue)
            }
            .onChange(of: scale) { _, newValue in
                guard abs(newValue - sliderValue) > 0.0001 else { return }
                sliderValue = newValue
            }
    }
}

private extension RecipeIngredientScaleControl {
    var formattedScale: String {
        ShoppingImportIngredientFormatter.formatScale(sliderValue)
    }

    var isDefaultScale: Bool {
        abs(sliderValue - 1.0) < 0.0001
    }

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
                Label("Scale Ingredients", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(formattedScale)x")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            }

            Slider(value: $sliderValue, in: 0.25...6.0, step: 0.25) {
                Text("Ingredient Scale")
            } minimumValueLabel: {
                Text("0.25x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("6x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .tint(tint)
            .accessibilityLabel("Ingredient scale")
            .accessibilityValue("\(formattedScale) times")

            HStack(spacing: 10) {
                if !isDefaultScale {
                    resetButton
                }

                Spacer()
                doneButton
            }
        }
    }

    @ViewBuilder
    var resetButton: some View {
        Button("Reset to 1x", action: onReset)
            .buttonStyle(.glass)
    }

    @ViewBuilder
    var doneButton: some View {
        Button("Done", action: onClose)
            .buttonStyle(.glassProminent)
    }
}
