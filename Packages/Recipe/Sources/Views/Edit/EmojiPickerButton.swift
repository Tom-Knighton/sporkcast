//
//  EmojiPickerButton.swift
//  Recipe
//
//  Created by Tom Knighton on 16/01/2026.
//

import SwiftUI
import Design

struct EmojiPickerButton: View {
    @Binding var emoji: String?
    @State private var isPicking = false
    
    var body: some View {
        Button { isPicking = true } label: {
            if let emoji {
                Text(emoji)
                    .font(.system(size: 28))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.tertiary))
            } else {
                Image(systemName: "face.dashed")
                    .font(.system(size: 28))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.tertiary))
            }
        }
        .overlay(alignment: .topTrailing, content: {
            ZStack {
                Circle().fill(.blue).frame(width: 15, height: 15)
                Image(systemName: "pencil")
                    .font(.caption2)
            }
            .padding(.top, -3)
            .padding(.trailing, -3)
        })
        .sheet(isPresented: $isPicking) {
            EmojiEntrySheet(value: $emoji, isPresented: $isPicking)
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
        }
    }
}
