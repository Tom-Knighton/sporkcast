//
//  OnboardingHeroView.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import SwiftUI

struct OnboardingHeroView: View {
    let step: OnboardingStep

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            Image(systemName: step.symbolName)
                .font(.system(size: 78, weight: .semibold))
                .foregroundStyle(step.tint)
                .frame(width: 172, height: 172)
                .glassEffect(.regular.tint(step.tint.opacity(0.12)), in: .circle)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 236)
    }
}

#Preview {
    OnboardingHeroView(step: OnboardingStep.all[0])
        .padding()
}
