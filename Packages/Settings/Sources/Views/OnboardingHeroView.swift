//
//  OnboardingHeroView.swift
//  Settings
//
//  Created by Tom Knighton on 29/05/2026.
//

import SwiftUI

struct OnboardingHeroView: View {
    let step: OnboardingStep
    var diameter: CGFloat = 140

    var body: some View {
        Image(systemName: step.symbolName)
            .font(.system(size: diameter * 0.45, weight: .semibold))
            .foregroundStyle(step.tint)
            .frame(width: diameter, height: diameter)
            .background(step.tint.opacity(0.12), in: .circle)
            .accessibilityHidden(true)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingHeroView(step: OnboardingStep.all[0])
        .padding()
}
