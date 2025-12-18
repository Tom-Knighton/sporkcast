//
//  NoteView.swift
//  RecipesList
//
//  Created by Tom Knighton on 18/12/2025.
//

import SwiftUI

struct NoteView: View {
    
    public let text: String
    
    var body: some View {
        VStack {
            Text(text)
                .padding(.all, 8)
                .frame(maxWidth: .infinity)
        }
        .background(Color.layer1.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.gray, lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: 10))
    }
}
