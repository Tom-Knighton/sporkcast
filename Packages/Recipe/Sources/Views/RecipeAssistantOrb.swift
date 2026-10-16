import SwiftUI

struct RecipeAssistantOrb: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.52), Color(white: 0.12), .black],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 48
                )
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.9), .clear, .white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                Image(systemName: "waveform")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .accessibilityHidden(true)
    }
}
