//
//  FlowLayout.swift
//  Design
//
//  Created by Tom Knighton on 26/09/2025.
//

import SwiftUI

public struct FlowLayout: Layout {
    var alignment: Alignment = .center
    var spacing: CGFloat = 10
    
    public init(alignment: Alignment, spacing: CGFloat) {
        self.alignment = alignment
        self.spacing = spacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        return result.bounds
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.size,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            // Adjust the frame origin to be relative to the bounds
            let adjustedOrigin = CGPoint(
                x: bounds.minX + frame.origin.x,
                y: bounds.minY + frame.origin.y
            )
            subview.place(at: adjustedOrigin, proposal: ProposedViewSize(frame.size))
        }
    }
    
    public struct FlowResult {
        var bounds = CGSize.zero
        var frames: [CGRect] = []
        
        public init(in containerSize: CGSize, subviews: LayoutSubviews, alignment: Alignment, spacing: CGFloat) {
            var origin = CGPoint.zero
            var lineHeight: CGFloat = 0
            var lineFrames: [CGRect] = []
            var allFrames: [CGRect] = []
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                // Check if we need to wrap to a new line
                if origin.x + size.width > containerSize.width && !lineFrames.isEmpty {
                    // Align the current line
                    alignLine(frames: &lineFrames, in: containerSize.width, alignment: alignment)
                    allFrames.append(contentsOf: lineFrames)
                    lineFrames.removeAll()
                    
                    // Start new line
                    origin.x = 0
                    origin.y += lineHeight + spacing
                    lineHeight = 0
                }
                
                let frame = CGRect(origin: origin, size: size)
                lineFrames.append(frame)
                lineHeight = max(lineHeight, size.height)
                origin.x += size.width + spacing
            }
            
            // Handle the last line
            if !lineFrames.isEmpty {
                alignLine(frames: &lineFrames, in: containerSize.width, alignment: alignment)
                allFrames.append(contentsOf: lineFrames)
            }
            
            self.frames = allFrames
            self.bounds = CGSize(
                width: containerSize.width,
                height: origin.y + lineHeight
            )
        }
        
        private func alignLine(frames: inout [CGRect], in width: CGFloat, alignment: Alignment) {
            guard !frames.isEmpty else { return }
            
            let totalWidth = frames.last!.maxX - frames.first!.minX - (frames.count > 1 ? 0 : 0)
            let availableSpace = width - totalWidth
            let leadingSpace = max(0, availableSpace * alignment.horizontal.percent)
            
            for i in frames.indices {
                frames[i].origin.x += leadingSpace
            }
        }
    }
}

public extension HorizontalAlignment {
    var percent: CGFloat {
        switch self {
        case .leading: return 0
        case .center: return 0.5
        case .trailing: return 1
        default: return 0.5
        }
    }
}
