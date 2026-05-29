//
//  OnboardingSlideView.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import SwiftUI

struct OnboardingSlideView: View {
    let step: OnboardingStep

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                OnboardingHeroView(step: step)
                    .padding(.top, 20)

                VStack(spacing: 12) {
                    Text(step.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GlassEffectContainer(spacing: 14) {
                    OnboardingFeatureListView(features: step.features, tint: step.tint)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 184)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingSlideView(step: OnboardingStep.all[3])
}
