//
//  ShoppingListAutoMoveToastView.swift
//  ShoppingLists
//
//  Created by Codex on 21/03/2026.
//

import SwiftUI

struct ShoppingListAutoMoveToastView: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Undo", action: onUndo)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.foreground)

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}
