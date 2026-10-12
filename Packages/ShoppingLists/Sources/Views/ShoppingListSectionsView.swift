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
    
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    var body: some View {
        GeometryReader { geo in
            let columnSpacing = hingeAwareSpacing(geometry: geo)
            
            let columns = Array(
                repeating: GridItem(
                    .flexible(),
                    spacing: columnSpacing
                ),
                count: horizontalSizeClass == .regular ? 2 : 1
            )

            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 12) {
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
    
    private func hingeAwareSpacing(
        geometry: GeometryProxy
    ) -> CGFloat {
        let defaultSpacing: CGFloat = 16
        
        if #available(iOS 27.1, *) {
            guard let hinge = geometry
                .reservedRegions(kind: .division)
                .first(where: \.isActive)
                    else {
                return defaultSpacing
            }
            
            return hinge.frame.width
            + hinge.margins.leading
            + hinge.margins.trailing
            + defaultSpacing
        }
        
        return defaultSpacing
    }
}
