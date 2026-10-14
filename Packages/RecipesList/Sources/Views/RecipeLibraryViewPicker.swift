import Environment
import SwiftUI

struct RecipeLibraryViewPicker: View {
    @Environment(\.recipeLibraryNavigation) private var library

    var body: some View {
        if let library, library.isSplitViewAvailable {
            @Bindable var library = library
            Picker("View", selection: $library.presentation) {
                ForEach(RecipeLibraryPresentation.allCases) { presentation in
                    Label(presentation.title, systemImage: presentation.symbol)
                        .tag(presentation)
                }
            }
        }
    }
}
