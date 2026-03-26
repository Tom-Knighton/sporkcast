//
//  ShoppingListAddItemBarView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI
import Design

struct ShoppingListAddItemBarView: View {
    let scheme: ColorScheme
    let onAddItem: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Add Item", systemImage: "plus", action: onAddItem)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Add item")
                .bold()
                .font(.title2)
                .padding(6)
                .foregroundStyle(.foreground)
                .frame(width: 44, height: 44)
                .buttonBorderShape(.circle)
                .buttonStyle(.glassProminent)
                .tint(scheme == .dark ? .black : .white)
        }
        .scenePadding()
    }
}
