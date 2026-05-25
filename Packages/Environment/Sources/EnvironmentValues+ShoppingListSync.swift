import SwiftUI

public extension EnvironmentValues {
    @Entry var shoppingListRemindersSync: any ShoppingListRemindersSyncing = ShoppingListRemindersSyncService.shared
    @Entry var mealplanCalendarSync: any MealplanCalendarSyncing = MealplanCalendarSyncService.shared
    @Entry var shoppingListMutations: ShoppingListMutationRepository = ShoppingListMutationRepository()
}
