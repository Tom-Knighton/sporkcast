import SwiftUI

struct RecipeCardSizing: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var rowHeight = 135

    let usesTileLayout: Bool

    func body(content: Content) -> some View {
        if usesTileLayout {
            content.aspectRatio(1.8, contentMode: .fit)
        } else {
            content.frame(height: rowHeight)
        }
    }
}
