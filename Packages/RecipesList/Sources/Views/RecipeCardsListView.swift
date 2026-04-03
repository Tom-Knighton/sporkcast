//
//  RecipeCardsListView.swift
//  RecipesList
//
//  Created by Codex on 27/03/2026.
//

import SwiftUI
import Design
import Models
import Environment

struct RecipeCardsListView: View {
    let recipes: [Recipe]
    let zoomNamespace: Namespace.ID
    let onOpen: (Recipe) -> Void
    let onDelete: (UUID) -> Void

    @Binding var showDeleteConfirmId: UUID?

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { showDeleteConfirmId != nil },
            set: { isPresented in
                if !isPresented {
                    showDeleteConfirmId = nil
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(recipes) { recipe in
                    NavigationLink(value: AppDestination.recipe(recipe: recipe)) {
                        RecipeCardView(recipe: recipe)
                            .matchedTransitionSource(id: "zoom-\(recipe.id.uuidString)", in: zoomNamespace)
                            .contentShape(.rect(cornerRadius: 20))
                            .containerShape(.rect(cornerRadius: 20))
                            .contextMenu {
                                Button(action: { onOpen(recipe) }) {
                                    Label("Open", systemImage: "hand.point.up")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    showDeleteConfirmId = recipe.id
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .tint(.red)
                                }
                            }
                            .confirmationDialog(
                                "Are you sure you want to delete this recipe? This cannot be undone.",
                                isPresented: alertIsPresented,
                                titleVisibility: .visible,
                                presenting: showDeleteConfirmId
                            ) { id in
                                Button(role: .destructive) {
                                    onDelete(id)
                                } label: {
                                    Text("Delete")
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}
