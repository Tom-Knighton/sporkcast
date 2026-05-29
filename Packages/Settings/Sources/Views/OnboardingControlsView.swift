//
//  OnboardingControlsView.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import SwiftUI

struct OnboardingControlsView: View {
    let selectedIndex: Int
    let totalSteps: Int
    let isLastStep: Bool
    let showsProCTA: Bool
    let next: () -> Void
    let finish: () -> Void
    let showPro: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 16) {
                OnboardingPageIndicatorView(selectedIndex: selectedIndex, totalSteps: totalSteps)

                if showsProCTA {
                    Button(action: showPro) {
                        Label("See Sporkast Pro", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)

                    Button(action: finish) {
                        Text("Start Cooking")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: next) {
                        Text(isLastStep ? "Start Cooking" : "Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)

                    Button(action: finish) {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(18)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

#Preview {
    OnboardingControlsView(
        selectedIndex: 3,
        totalSteps: 4,
        isLastStep: true,
        showsProCTA: true,
        next: {},
        finish: {},
        showPro: {}
    )
    .padding()
}
