enum SettingsDestination: Hashable {
    case general
    case recipes
    case mealplan
    case discovery
    case groceries
    case weather
    case pro
    #if DEBUG
    case database
    #endif
}
