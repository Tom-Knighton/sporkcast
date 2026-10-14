import SwiftUI

public extension View {
    /// Uses native swipe actions on iOS 27, retaining Swipy on iOS 26.
    @ContentBuilder
    func adaptiveDeleteSwipeAction(perform action: @escaping () -> Void) -> some View {
        if #available(iOS 27.0, *) {
            self.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                // A destructive role can dismiss the row before a confirmation completes.
                Button(action: action) {
                    Label("Delete", systemImage: "trash")
                        .fixedSize()
                }
                .tint(.red)
            }
        } else {
            SwipeView {
                self
            } trailingActions: { _ in
                SwipeAction(action: action) { _ in
                    Label("Delete", systemImage: "trash")
                } background: { _ in
                    Color.red
                }
                .allowSwipeToTrigger()
            }
        }
    }

    /// Enables native row swipe actions in a custom scroll container.
    @ContentBuilder
    func adaptiveSwipeActionsContainer() -> some View {
        if #available(iOS 27.0, *) {
            self.swipeActionsContainer()
        } else {
            self
        }
    }
}
