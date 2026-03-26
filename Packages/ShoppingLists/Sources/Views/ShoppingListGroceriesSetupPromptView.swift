//
//  ShoppingListGroceriesSetupPromptView.swift
//  ShoppingLists
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI
import Design

struct ShoppingListGroceriesSetupPromptView: View {
    @Binding var isPresented: Bool
    let onAcknowledge: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.layer1.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Set List To Groceries")
                        .font(.title3.bold())

                    Text("(Optional) To enable automatic grocery categorisation in Reminders, open the 'Sporkast Shopping' list in Apple Reminders and set the list type to Shopping/Groceries.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("This only needs to be done once.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Button("I've Done This", action: onAcknowledge)
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                        .tint(.blue)
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .padding(20)
            }
            .navigationTitle("Reminders Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
