import SwiftUI
import UIKit

struct RecipeSectionPicker: View {
    @Binding var selection: Int
    let usesCookingColumns: Bool
    let suggestionsImage: UIImage?
    let showsChat: Bool

    var body: some View {
        Picker("Recipe section", selection: $selection) {
            Text(usesCookingColumns ? "Recipe" : "Ingredients").tag(1)
            if !usesCookingColumns {
                Text("Steps").tag(2)
            }
            if let suggestionsImage {
                Image(uiImage: suggestionsImage)
                    .accessibilityLabel("Suggestions")
                    .tag(3)
            } else {
                Text("Suggestions").tag(3)
            }
            if showsChat {
                Text("Chat").tag(4)
            }
        }
        .pickerStyle(.segmented)
    }
}
