import SwiftUI

struct RecipeChatView: View {
    @Environment(RecipeViewModel.self) private var viewModel
    @State private var draftMessage = ""
    @State private var responseTask: Task<Void, Never>?
    @State private var showsResetConfirmation = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        RecipeAssistantOrb()
                        Text("Recipe assistant")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.bottom, 8)
                    Text(viewModel.recipeChatMessages.isEmpty ? "Make it your own." : "Let’s talk cooking.")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    Text("Substitutions, a head start, or a tricky step. Let's make this recipe work for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !viewModel.recipeChatMessages.isEmpty {
                    Menu("Chat options", systemImage: "ellipsis") {
                        Button("New conversation", systemImage: "square.and.pencil") {
                            showsResetConfirmation = true
                        }
                        ShareLink("Share conversation", item: viewModel.recipeChatMessages.map {
                            "\($0.role == .user ? "You" : "Sporkast"): \($0.content)"
                        }.joined(separator: "\n\n"))
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }

            if !viewModel.recipeChatMessages.isEmpty {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.recipeChatMessages) { message in
                        RecipeChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .scrollTargetLayout()
            }

            if viewModel.recipeChatResponding {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Working on your recipe…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if let error = viewModel.recipeChatError {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    if viewModel.recipeChatMessages.last?.role == .user {
                        Button("Try again", systemImage: "arrow.clockwise") {
                            responseTask = Task { await viewModel.retryRecipeChat() }
                        }
                        .disabled(viewModel.recipeChatResponding)
                    }
                }
                .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 10) {
                RecipeChatComposer(
                    message: $draftMessage,
                    isSending: viewModel.recipeChatResponding,
                    isAvailable: viewModel.supportsRecipeChat,
                    focus: $composerFocused,
                    onSend: sendDraft,
                    onStop: stopResponse
                )
                Label(
                    viewModel.recipeChatRoute ?? viewModel.intelligence.availabilityDescription,
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .id("recipe-chat-composer")

            if viewModel.recipeChatMessages.isEmpty {
                RecipeChatPromptSuggestions(
                    prompts: viewModel.recipeChatSuggestedPrompts,
                    isDisabled: !viewModel.supportsRecipeChat || viewModel.recipeChatResponding,
                    onTap: sendPrompt
                )
            }
        }
        .padding(20)
        .background(RecipeAssistantStyle.surface, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(RecipeAssistantStyle.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .fontDesign(.default)
        .tint(.primary)
        .confirmationDialog("Start a new conversation?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("New conversation", role: .destructive) {
                stopResponse()
                viewModel.clearRecipeChat()
            }
        } message: {
            Text("This will clear the messages in this recipe's chat.")
        }
        .onDisappear { stopResponse() }
    }

    private func sendDraft() {
        let prompt = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, prompt.count <= 2000,
              !viewModel.recipeChatResponding, viewModel.supportsRecipeChat else { return }
        draftMessage = ""
        sendPrompt(prompt)
    }

    private func sendPrompt(_ prompt: String) {
        guard !viewModel.recipeChatResponding else { return }
        composerFocused = false
        responseTask = Task { await viewModel.sendRecipeChatMessage(prompt) }
    }

    private func stopResponse() {
        responseTask?.cancel()
        responseTask = nil
        if viewModel.recipeChatResponding { viewModel.cancelRecipeChat() }
    }
}
