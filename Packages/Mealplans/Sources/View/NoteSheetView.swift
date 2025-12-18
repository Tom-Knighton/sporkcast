//
//  NoteSheetView.swift
//  Mealplans
//
//  Created by Tom Knighton on 18/12/2025.
//

import SwiftUI

struct NoteSheetView: View {
    
    let initialText: String
    let title: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var text: String
    @FocusState private var fieldFocus: Bool
    
    init(
        initialText: String,
        title: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialText = initialText
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        self._text = State(initialValue: initialText)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Add a note…", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.separator, lineWidth: 1)
                    }
                    .padding(.horizontal)
                    .focused($fieldFocus)
                
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(text) }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            self.fieldFocus = true
        }
    }
}
