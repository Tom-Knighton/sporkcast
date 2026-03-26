//
//  ShoppingListItemRowView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 21/03/2026.
//

import SwiftUI
import Models

struct ShoppingListItemRowView: View {
    let item: ShoppingListItem
    let focusedRow: FocusState<String?>.Binding
    let suggestion: ShoppingCategory?
    let onToggleCompletion: (ShoppingListItem) -> Void
    let onSubmitTitle: (ShoppingListItem, String) -> Void
    let onAcceptSuggestion: (ShoppingListItem, ShoppingCategory) -> Void

    @State private var titleText: String

    init(
        item: ShoppingListItem,
        focusedRow: FocusState<String?>.Binding,
        suggestion: ShoppingCategory?,
        onToggleCompletion: @escaping (ShoppingListItem) -> Void,
        onSubmitTitle: @escaping (ShoppingListItem, String) -> Void,
        onAcceptSuggestion: @escaping (ShoppingListItem, ShoppingCategory) -> Void
    ) {
        self.item = item
        self.focusedRow = focusedRow
        self.suggestion = suggestion
        self.onToggleCompletion = onToggleCompletion
        self.onSubmitTitle = onSubmitTitle
        self.onAcceptSuggestion = onAcceptSuggestion
        self._titleText = State(initialValue: item.title)
    }

    private var focusIdentifier: String {
        item.id.uuidString
    }

    private var isMarkedComplete: Bool {
        item.isComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                completionButton
                    .padding(.top, 2)

                TextField("Item", text: $titleText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(isMarkedComplete ? .secondary : .primary)
                    .strikethrough(isMarkedComplete, pattern: .solid, color: .secondary)
                    .focused(focusedRow, equals: focusIdentifier)
                    .submitLabel(.done)
                    .onSubmit(submitTitleIfNeeded)
                    .onChange(of: focusedRow.wrappedValue) { oldValue, newValue in
                        if oldValue == focusIdentifier, newValue != focusIdentifier {
                            submitTitleIfNeeded()
                        }
                    }
                    .onChange(of: item.title) { _, newValue in
                        titleText = newValue
                    }
            }
            .padding(.vertical, 8)

            if let suggestion, shouldShowSuggestionButton(for: suggestion) {
                Button("Move to \(suggestion.displayName)") {
                    onAcceptSuggestion(item, suggestion)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(.blue)
                .accessibilityLabel("Move item to \(suggestion.displayName)")
            }
        }
    }
}

private extension ShoppingListItemRowView {

    var completionButton: some View {
        Button(
            isMarkedComplete ? "Completed" : "Mark complete",
            systemImage: isMarkedComplete ? "checkmark.circle.fill" : "circle",
            action: toggleCompletion
        )
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(isMarkedComplete ? .green : .secondary)
        .accessibilityLabel(isMarkedComplete ? "Completed" : "Mark complete")
    }

    func shouldShowSuggestionButton(for suggestion: ShoppingCategory) -> Bool {
        suggestion != ShoppingCategory(categoryIdentifier: item.categoryId)
    }

    func submitTitleIfNeeded() {
        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            titleText = item.title
            return
        }

        guard trimmed != item.title else {
            return
        }

        onSubmitTitle(item, trimmed)
    }

    func toggleCompletion() {
        onToggleCompletion(item)
    }
}
