//
//  ShoppingListSectionsView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI
import Models
import Environment
import Design

struct ShoppingListSectionsView: View {
    let sections: [ShoppingListDisplaySection]
    let focusedRow: FocusState<String?>.Binding
    let reclassificationSuggestions: [UUID: ShoppingCategory]
    let remindersSnapshot: ShoppingListRemindersSyncSnapshot
    let onSyncNow: () -> Void
    let onToggleCompletion: (ShoppingListItem) -> Void
    let onSubmitTitle: (ShoppingListItem, String) -> Void
    let onSubmitNewItem: (ShoppingListItemGroup, String) -> Void
    let onAcceptSuggestion: (ShoppingListItem, ShoppingCategory) -> Void
    let onDropItem: (UUID, ShoppingCategory) -> Bool

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 12) {
//                    ShoppingListRemindersStatusCardView(
//                        snapshot: remindersSnapshot,
//                        onSyncNow: onSyncNow
//                    )

                    ForEach(sections) { section in
                        ShoppingListSectionView(
                            section: section.section,
                            visibleItems: section.visibleItems,
                            focusedRow: focusedRow,
                            reclassificationSuggestions: reclassificationSuggestions,
                            onToggleCompletion: onToggleCompletion,
                            onSubmitTitle: onSubmitTitle,
                            onSubmitNewItem: onSubmitNewItem,
                            onAcceptSuggestion: onAcceptSuggestion,
                            onDropItem: onDropItem
                        )
                    }   
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }
}
