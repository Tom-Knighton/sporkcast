//
//  OnboardingPageIndicatorView.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import SwiftUI

struct OnboardingPageIndicatorView: View {
    let selectedIndex: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: index == selectedIndex ? 24 : 7, height: 7)
                    .animation(.snappy, value: selectedIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding page \(selectedIndex + 1) of \(totalSteps)")
    }
}

#Preview {
    OnboardingPageIndicatorView(selectedIndex: 1, totalSteps: 4)
}
