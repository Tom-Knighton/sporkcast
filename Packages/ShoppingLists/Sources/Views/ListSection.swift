//
//  ListSection.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 22/02/2026.
//

import SwiftUI
import Models
import Observation

struct ListSection: View {
    @Environment(\.shoppingList) private var shoppingList: ShoppingList?
    @Binding var section: ShoppingListItemGroup
    var focusedRow: FocusState<String?>.Binding
    @State private var isExpanded = true
    @State private var newRowText: String = ""
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach($section.items) { item in
                AddItemRow(sectionName: section.names.first ?? "Other", id: item.id.uuidString, text: item.title, focusedRow: focusedRow) { newVal in
                    
                }
            }
            AddItemRow(sectionName: "Other", id: "addrow-\(section.id)", text: $newRowText, focusedRow: focusedRow, isNewRow: true) { newVal in
                section.items.append(.init(id: UUID(), title: newVal, isComplete: false, categoryId: section.id, categoryName: section.names.first ?? "Other", categorySource: "manual"))
                newRowText = ""
                print("Input")
            }
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
    @Binding var text: String
    var isNewRow: Bool = false
    let id: String
    
    var onSubmit: (String) -> Void
    
    init(sectionName: String, id: String, text: Binding<String>, focusedRow: FocusState<String?>.Binding, isNewRow: Bool = false, onSubmit: @escaping (String) -> Void) {
        self.sectionName = sectionName
        self.focusedRow = focusedRow
        self._text = text
        self.isNewRow = isNewRow
        self.id = id
        self.onSubmit = onSubmit
    }
    
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
                                self.onSubmit(text)
                            }
                        })
                        .scrollDisabled(true)
                        .focused(focusedRow, equals: id)
                        
                }
        }
        .foregroundStyle(isNewRow ? Color.gray : Color.primary)
        .padding(.vertical, 8)
    }
}
