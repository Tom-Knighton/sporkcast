//
//  ShoppingListInputRowView.swift
//  ShoppingLists
//
//  Created by Codex on 21/03/2026.
//

import SwiftUI
import Models

struct ShoppingListInputRowView: View {
    let section: ShoppingListItemGroup
    let focusedRow: FocusState<String?>.Binding
    let onSubmit: (ShoppingListItemGroup, String) -> Void

    @State private var text = ""

    private var focusIdentifier: String {
        "addrow-\(section.id)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            TextField("Add item", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(focusedRow, equals: focusIdentifier)
                .submitLabel(.done)
                .onSubmit(submit)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }
}

private extension ShoppingListInputRowView {

    func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        onSubmit(section, trimmed)
        text = ""
        focusedRow.wrappedValue = focusIdentifier
    }
}
