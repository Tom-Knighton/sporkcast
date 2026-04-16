//
//  RecipeChatView.swift
//  Recipe
//
//  Created by Tom Knighton on 12/04/2026.
//

import SwiftUI
import Design

struct RecipeChatView: View {
    @Environment(RecipeViewModel.self) private var viewModel
    @State private var draftMessage = ""

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recipe Chat")
                        .font(.title3.bold())
                    Spacer()
                    if viewModel.recipeChatMessages.isEmpty == false {
                        Button("New Chat") {
                            viewModel.clearRecipeChat()
                        }
                        .buttonStyle(.glass)
                        .font(.footnote)
                    }
                }

                Text("Ask about substitutions, timings, prep strategy, or cooking adjustments for this recipe.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.recipeChatSuggestedPrompts.isEmpty == false {
                RecipeChatPromptSuggestions(
                    prompts: viewModel.recipeChatSuggestedPrompts,
                    isDisabled: viewModel.recipeChatResponding,
                    onTap: sendPrompt
                )
            }

            if let error = viewModel.recipeChatError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }

            recipeMessages
            RecipeChatComposer(
                message: $draftMessage,
                isSending: viewModel.recipeChatResponding,
                onSend: sendDraft
            )
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .intelligenceBackground(in: .rect(cornerRadius: 16), animated: false)
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private var recipeMessages: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 10) {
                    if viewModel.recipeChatMessages.isEmpty {
                        RecipeChatEmptyState()
                    } else {
                        ForEach(viewModel.recipeChatMessages) { message in
                            RecipeChatBubble(message: message)
                        }
                    }

                    if viewModel.recipeChatResponding {
                        RecipeChatThinkingBubble()
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("recipe-chat-bottom")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 320)
            .onChange(of: viewModel.recipeChatMessages.count, initial: true) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("recipe-chat-bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.recipeChatResponding) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("recipe-chat-bottom", anchor: .bottom)
                }
            }
        }
    }

    private func sendDraft() {
        let trimmed = draftMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        draftMessage = ""
        Task {
            await viewModel.sendRecipeChatMessage(trimmed)
        }
    }

    private func sendPrompt(_ prompt: String) {
        Task {
            await viewModel.sendRecipeChatMessage(prompt)
        }
    }
}

private struct RecipeChatPromptSuggestions: View {
    let prompts: [String]
    let isDisabled: Bool
    let onTap: (String) -> Void

    var body: some View {
        HorizontalScrollWithGradient {
            ForEach(prompts, id: \.self) { prompt in
                Button(action: { onTap(prompt) }) {
                    Text(prompt)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Material.thin)
                        .clipShape(.capsule)
                }
                .font(.footnote)
                .disabled(isDisabled)
            }
        }
    }
}

private struct RecipeChatBubble: View {
    let message: RecipeChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 28)
            }

            Text(message.content)
                .textSelection(.enabled)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isUser ? Material.thin : Material.regular)
                .clipShape(.rect(cornerRadius: 12))

            if isUser == false {
                Spacer(minLength: 28)
            }
        }
    }
}

private struct RecipeChatThinkingBubble: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Thinking...")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Material.regular)
        .clipShape(.rect(cornerRadius: 12))
    }
}

private struct RecipeChatEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ask this recipe anything", systemImage: "text.bubble")
                .font(.subheadline.weight(.semibold))
            Text("Try substitutions, timing tweaks, or scaling questions - or ask clarifying questions about ingredients or steps.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Material.regular)
        .clipShape(.rect(cornerRadius: 12))
    }
}

private struct RecipeChatComposer: View {
    @Binding var message: String
    let isSending: Bool
    let onSend: () -> Void

    private var canSend: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isSending == false
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask about this recipe", text: $message, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Material.regular, in: .rect(cornerRadius: 10))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canSend ? Color.primary : Color.secondary)
            .disabled(canSend == false)
        }
    }
}
