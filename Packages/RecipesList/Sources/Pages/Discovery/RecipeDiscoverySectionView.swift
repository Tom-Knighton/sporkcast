//
//  RecipeDiscoverySectionView.swift
//  RecipesList
//

import API
import SwiftUI

struct RecipeDiscoverySectionView: View {
    let section: DiscoveryFeedSection
    let importingItemID: String?
    let onOpen: (DiscoveryFeedItem) -> Void
    let onAdd: (DiscoveryFeedItem) -> Void
    let onHide: (DiscoveryFeedItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(section.items) { item in
                        RecipeDiscoveryCard(
                            item: item,
                            isImporting: importingItemID == item.id,
                            onOpen: { onOpen(item) },
                            onAdd: { onAdd(item) },
                            onHide: { onHide(item) }
                        )
                    }
                }
                .padding(.horizontal, 18)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}
