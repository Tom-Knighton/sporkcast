//
//  OnboardingFeatureListView.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import SwiftUI

struct OnboardingFeatureListView: View {
    let features: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(features, id: \.self) { feature in
                Label(feature, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .labelStyle(.titleAndIcon)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(tint, .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: 14))
            }
        }
    }
}

#Preview {
    OnboardingFeatureListView(features: OnboardingStep.all[0].features, tint: .orange)
        .padding()
}
