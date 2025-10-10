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
    @State private var hasMoreToScroll = false
    
    public init(@ViewBuilder content: () -> Content) {
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
        } action: { newMetrics, _ in
            metrics = newMetrics
            let endVisibleX = metrics.offsetX + metrics.containerWidth
            withAnimation {
                self.hasMoreToScroll = metrics.contentWidth > metrics.containerWidth && endVisibleX < metrics.contentWidth - 1
            }
        }
        .mask(LinearGradient(gradient: Gradient(colors: [.black, .black, .black, hasMoreToScroll ? .clear : .black]), startPoint: .leading, endPoint: .trailing))
    }
}
