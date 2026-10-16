import Design
import SwiftUI

struct RecipeChatPromptSuggestions: View {
    let prompts: [RecipeChatSuggestion]
    let isDisabled: Bool
    let onTap: (String) -> Void

    var body: some View {
        HorizontalScrollWithGradient {
            HStack(spacing: 10) {
                ForEach(prompts) { suggestion in
                    Button { onTap(suggestion.prompt) } label: {
                        Label(suggestion.title, systemImage: suggestion.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)
                            .background(.quaternary.opacity(0.35), in: .capsule)
                            .overlay {
                                Capsule()
                                    .strokeBorder(RecipeAssistantStyle.border, lineWidth: 1)
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .accessibilityLabel(suggestion.prompt)
                }
            }
        }
    }
}
