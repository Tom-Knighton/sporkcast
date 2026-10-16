import SwiftUI

struct RecipeChatComposer: View {
    @Binding var message: String
    let isSending: Bool
    let isAvailable: Bool
    let focus: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onStop: () -> Void

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && message.count <= 2000 && isAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask about this recipe…", text: $message, axis: .vertical)
                    .lineLimit(1...6)
                    .focused(focus)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 12)
                    .disabled(!isAvailable)
                    .accessibilityLabel("Question about this recipe")
                if isSending {
                    Button("Stop response", systemImage: "stop.circle.fill", action: onStop)
                        .labelStyle(.iconOnly)
                        .font(.title)
                        .frame(minWidth: 44, minHeight: 44)
                } else {
                    Button("Send question", systemImage: "arrow.up.circle.fill", action: onSend)
                        .labelStyle(.iconOnly)
                        .font(.title)
                        .foregroundStyle(canSend ? Color.primary : Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!canSend)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            if message.count > 2000 {
                Text("Keep your question under 2,000 characters.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
