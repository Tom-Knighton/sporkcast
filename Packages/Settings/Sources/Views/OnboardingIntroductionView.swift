import SwiftUI

struct OnboardingIntroductionView: View {
    let step: OnboardingStep
    let heroDiameter: CGFloat
    let usesCompactTitle: Bool

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeroView(step: step, diameter: heroDiameter)

            VStack(spacing: 12) {
                Text(step.title)
                    .font(usesCompactTitle ? .title.bold() : .largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(step.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
        }
    }
}
