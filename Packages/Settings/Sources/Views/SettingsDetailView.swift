import SwiftUI
import Design

struct SettingsDetailView: View {
    let selection: SettingsDestination?

    var body: some View {
        Group {
            switch selection {
            case .general:
                GeneralSettingsPage()
            case .recipes:
                RecipesSettingsPage()
            case .mealplan:
                MealplanSettingsPage()
            case .discovery:
                DiscoverySettingsPage()
            case .groceries:
                GroceriesSettingsPage()
            case .weather:
                WeatherSettingsPage()
            case .pro:
                ProSettingsPage()
            #if DEBUG
            case .database:
                DatabaseDebugViewerPage()
            #endif
            case nil:
                ContentUnavailableView(
                    "Select a Setting",
                    systemImage: "gearshape",
                    description: Text("Choose a category to view and update your settings.")
                )
                .navigationTitle("Settings")
            }
        }
        .modifier(RecipeNavigationBarBehavior())
        .background(Color.layer1)
    }
}
