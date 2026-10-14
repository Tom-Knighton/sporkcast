import SwiftUI

struct RecipeNavigationBarBehavior: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
