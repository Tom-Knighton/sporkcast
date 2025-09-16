//
//  View+StretchyHeader.swift
//  Design
//
//  Created by Tom Knighton on 24/08/2025.
//

import SwiftUI

public extension View {
    func stretchy() -> some View {
        self
            .visualEffect { effect, geometry in
                let currentHeight = geometry.size.height
                let scrollOffset = geometry.frame(in: .scrollView).minY
                let positiveOffset = max(0, scrollOffset)
                
                let newHeight = currentHeight + positiveOffset
                let scaleFactor = newHeight / currentHeight
                
                return effect.scaleEffect(
                    x: scaleFactor, y: scaleFactor,
                    anchor: .bottom
                )
            }
    }
}
