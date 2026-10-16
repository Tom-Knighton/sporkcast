//
//  HorizontalScrollWithGradient.swift
//  Design
//
//  Created by Tom Knighton on 26/09/2025.
//
import SwiftUI

public struct HorizontalScrollWithGradient<Content: View>: View {
    struct Metrics: Equatable {
        var offsetX: CGFloat
        var contentWidth: CGFloat
        var containerWidth: CGFloat
    }
    
    let content: Content
    @State private var metrics = Metrics(offsetX: 0, contentWidth: 0, containerWidth: 0)
    @Environment(\.layoutDirection) private var layoutDirection
    
    public init(@ContentBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
        .onScrollGeometryChange(for: Metrics.self) { g in
            Metrics(
                offsetX: max(0, g.contentOffset.x),
                contentWidth: g.contentSize.width,
                containerWidth: g.containerSize.width
            )
        } action: { _, newMetrics in
            metrics = newMetrics
        }
        .mask {
            let overflows = metrics.contentWidth > metrics.containerWidth + 1
            let hasContentBefore = overflows && metrics.offsetX > 1
            let hasContentAfter = overflows && metrics.offsetX + metrics.containerWidth < metrics.contentWidth - 1
            let fadesLeading = layoutDirection == .leftToRight ? hasContentBefore : hasContentAfter
            let fadesTrailing = layoutDirection == .leftToRight ? hasContentAfter : hasContentBefore
            let fadeFraction = min(24 / max(metrics.containerWidth, 1), 0.5)

            LinearGradient(
                stops: [
                    .init(color: fadesLeading ? .clear : .black, location: 0),
                    .init(color: .black, location: fadeFraction),
                    .init(color: .black, location: 1 - fadeFraction),
                    .init(color: fadesTrailing ? .clear : .black, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
