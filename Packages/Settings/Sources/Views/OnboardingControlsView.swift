//
//  OnboardingControlsView.swift
//  Settings
//
//  Created by Tom Knighton on 29/05/2026.
//

import SwiftUI

struct OnboardingControlsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedIndex: Int
    let totalSteps: Int
    let isLastStep: Bool
    let showsProCTA: Bool
    let next: () -> Void
    let finish: () -> Void
    let showPro: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 10) {
                OnboardingPageIndicatorView(selectedIndex: selectedIndex, totalSteps: totalSteps)

                let actionsLayout = !dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(HStackLayout(spacing: 12))
                    : AnyLayout(VStackLayout(spacing: 12))

                actionsLayout {
                    if showsProCTA {
                        Button(action: showPro) {
                            Label("Explore Pro", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .frame(maxWidth: 240, minHeight: 44)

                        Button(action: finish) {
                            Text("Start Cooking")
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    } else {
                        Button(action: next) {
                            Text(isLastStep ? "Start Cooking" : "Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .frame(maxWidth: 240, minHeight: 44)

                        Button(action: finish) {
                            Text("Skip")
                                .padding(.horizontal, 12)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
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
