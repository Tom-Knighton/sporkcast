//
//  ShoppingListSectionView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 21/03/2026.
//

import SwiftUI
import Models

struct ShoppingListSectionView: View {
    let section: ShoppingListItemGroup
    let visibleItems: [ShoppingListItem]
    let focusedRow: FocusState<String?>.Binding
    let reclassificationSuggestions: [UUID: ShoppingCategory]
    let onToggleCompletion: (ShoppingListItem) -> Void
    let onSubmitTitle: (ShoppingListItem, String) -> Void
    let onSubmitNewItem: (ShoppingListItemGroup, String) -> Void
    let onAcceptSuggestion: (ShoppingListItem, ShoppingCategory) -> Void
    let onDropItem: (UUID, ShoppingCategory) -> Bool

    @State private var isExpanded = true
    @State private var isDropTargeted = false

    private var sectionCategory: ShoppingCategory {
        ShoppingCategory(categoryIdentifier: section.id)
    }

    private var sectionDisplayName: String {
        section.names.first ?? sectionCategory.displayName
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(visibleItems) { item in
                    HStack(spacing: 8) {
                        ShoppingListItemRowView(
                            item: item,
                            focusedRow: focusedRow,
                            suggestion: reclassificationSuggestions[item.id],
                            onToggleCompletion: onToggleCompletion,
                            onSubmitTitle: onSubmitTitle,
                            onAcceptSuggestion: onAcceptSuggestion
                        )

                        Image(systemName: "line.3.horizontal")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Drag \(item.title)")
                    }
                    .contentShape(.rect)
                    .draggable(ShoppingItemDragPayload(itemId: item.id))

                    if item.id != visibleItems.last?.id {
                        Divider()
                    }
                }

                if !visibleItems.isEmpty {
                    Divider()
                }

                ShoppingListInputRowView(
                    section: section,
                    focusedRow: focusedRow,
                    onSubmit: onSubmitNewItem
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(
                isDropTargeted
                ? .regular.tint(.blue.opacity(0.25)).interactive()
                : .regular,
                in: .rect(cornerRadius: 18)
            )
        } label: {
            HStack(spacing: 8) {
                Text(sectionDisplayName)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                if !visibleItems.isEmpty {
                    Text("\(visibleItems.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quinary, in: Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .disclosureGroupStyle(.automatic)
        .dropDestination(for: ShoppingItemDragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            return onDropItem(payload.itemId, sectionCategory)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
    }
}
