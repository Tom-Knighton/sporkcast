//
//  ListSection.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 22/02/2026.
//

import SwiftUI
import Models

struct ListSection: View {
    @Binding var section: ShoppingListItemGroup
    var focusedRow: FocusState<String?>.Binding
    @State private var isExpanded = true
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach($section.items) { item in
                ListItemView(item: item, focusedRow: focusedRow)
            }
            AddItemRow(sectionName: "other", focusedRow: focusedRow)
        } label: {
            Text(section.names.first ?? "Other")
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
    }
}

struct AddItemRow: View {
    let sectionName: String
    var focusedRow: FocusState<String?>.Binding
    @State var text: String = ""
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "circle.dashed")
            Text(text.isEmpty ? " " : text) // Defaults to preserve space/height
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    TextEditor(text: $text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, -5)
                        .submitLabel(.return)
                        .scrollContentBackground(.hidden)
                        .onChange(of: text, { _, newValue in
                            if let last = newValue.last, last == "\n" {
                                text.removeLast()
                                focusedRow.wrappedValue = nil
                            }
                        })
                        .scrollDisabled(true)
                        .focused(focusedRow, equals: "addrow-\(sectionName)")
                        
                }
        }
        .foregroundStyle(.placeholder)
        .padding(.vertical, 8)
    }
}

struct ListItemView: View {
    @Binding var item: ShoppingListItem
    var focusedRow: FocusState<String?>.Binding

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "circle")
            Text(item.title.isEmpty ? " " : item.title) // Defaults to preserve space/height
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)
//                .onChange(of: attributed) { _, newValue in
//                    let v = String(newValue.characters)
//                    ingredient.ingredientText = v
//                    self.parseIngredientText(v)
//                }
//                .onChange(of: ingredient, initial: true) { _, newValue in
//                    attributed = IngredientHighlighter.highlight(
//                        ingredient: ingredient,
//                        font: .body,
//                        tint: .secondary
//                    )
//                }
                .overlay {
                    TextEditor(text: $item.title)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, -5)
                        .submitLabel(.return)
                        .scrollContentBackground(.hidden)
                        .onChange(of: item.title, { _, newValue in
                            if let last = newValue.last, last == "\n" {
                                item.title.removeLast()
                                focusedRow.wrappedValue = nil
                            }
                        })
                        .focused(focusedRow, equals: item.id.uuidString)
                        .scrollDisabled(true)
//                        .focused(focusedID, equals: ingredient.id)
                }
        }
        .padding(.vertical, 8)
    }
}
