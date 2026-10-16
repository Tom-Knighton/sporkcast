import SwiftUI

struct RecipeChatBubble: View {
    let message: RecipeChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message.role == .user ? "You" : "Sporkast", systemImage: message.role == .user ? "person.crop.circle" : "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if message.role == .user {
                Text(message.content)
                    .padding(14)
                    .background(.quaternary, in: .rect(cornerRadius: 16))
            } else {
                Text(.init(message.content))
                    .tint(.primary)
            }
        }
        .font(.body)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .contextMenu {
            ShareLink("Share message", item: message.content)
        }
    }
}
