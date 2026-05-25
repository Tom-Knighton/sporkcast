//
//  RecipeDiscoveryCard.swift
//  RecipesList
//

import API
import SwiftUI

struct RecipeDiscoveryCard: View {
    let item: DiscoveryFeedItem
    let isImporting: Bool
    let onOpen: () -> Void
    let onAdd: () -> Void
    let onHide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                RecipeDiscoveryImage(item: item)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(item.title)")

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: 44, alignment: .topLeading)

                HStack(spacing: 8) {
                    Label(item.sourceDomain, systemImage: "globe")
                        .lineLimit(1)

                    if let totalMinutes = item.totalMinutes {
                        Label("\(Int(totalMinutes))m", systemImage: "clock")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let reason = item.reason {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .topLeading)
                } else {
                    Spacer(minLength: 36)
                }
            }

            HStack(spacing: 10) {
                Button(action: onAdd) {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Add", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isImporting)

                Menu {
                    Button("Open Source", systemImage: "safari", action: onOpen)
                    Button("Hide", systemImage: "eye.slash", role: .destructive, action: onHide)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 38, height: 34)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("More actions for \(item.title)")
            }
        }
        .padding(12)
        .frame(width: 268, height: 338, alignment: .top)
        .contentShape(.rect(cornerRadius: 18))
        .modifier(DiscoveryGlassSurface())
    }
}

private struct RecipeDiscoveryImage: View {
    let item: DiscoveryFeedItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.22),
                            Color.green.opacity(0.18),
                            Color.blue.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: 132)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.title.weight(.semibold))
            Text(item.sourceDomain)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(14)
    }
}

struct DiscoveryGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}
