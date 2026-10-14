//
//  OnboardingSlideView.swift
//  Settings
//
//  Created by Tom Knighton on 29/05/2026.
//

import SwiftUI

struct OnboardingSlideView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let step: OnboardingStep

    var body: some View {
        GeometryReader { geometry in
            // Use the space offered by the container, including when Duo changes size.
            let usesColumns = geometry.size.width >= 700 && !dynamicTypeSize.isAccessibilitySize
            let isCompact = geometry.size.height < 600 || geometry.size.width < 380
            let layout = usesColumns
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 40))
                : AnyLayout(VStackLayout(spacing: 24))

            ScrollView {
                layout {
                    OnboardingIntroductionView(
                        step: step,
                        heroDiameter: isCompact ? 104 : 140,
                        usesCompactTitle: usesColumns
                    )
                    .frame(maxWidth: .infinity)

                    OnboardingFeatureListView(features: step.features, tint: step.tint)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: usesColumns ? 960 : 560)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    OnboardingSlideView(step: OnboardingStep.all[3])
}
