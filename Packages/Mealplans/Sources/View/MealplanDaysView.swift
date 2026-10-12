import Environment
import Models
import SwiftUI

struct MealplanDaysView: View {
    @Environment(\.calendar) private var calendar

    let days: [Date]
    let entries: [MealplanEntry]
    let currentDate: Date
    let selectedDay: Date?
    let weatherService: MealplanWeatherService?
    let shouldGreyOutPastDays: Bool
    @Binding var isDraggingEntry: Bool
    @Binding var scrollPosition: ScrollPosition
    @Binding var hasScrolledToToday: Bool
    let onAddMeal: (Date) -> Void
    let onDayAppeared: (Date) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack {
                    ForEach(days, id: \.self) { day in
                        MealplanRowView(
                            for: day,
                            with: entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
                                .sorted { $0.index < $1.index },
                            currentDate: currentDate,
                            weather: weatherService?.forecast(for: day, calendar: calendar),
                            shouldGreyOutPastDays: shouldGreyOutPastDays,
                            isDraggingEntry: $isDraggingEntry,
                            isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false,
                            onAddMeal: selectedDay == nil ? nil : { onAddMeal(day) },
                            onSelectDay: selectedDay == nil ? nil : { onAddMeal(day) }
                        )
                        .id(day)
                        .onAppear { onDayAppeared(day) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition($scrollPosition)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .environment(\.isMealplanDragging, isDraggingEntry)
            .task {
                guard !hasScrolledToToday else { return }
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
                reader.scrollTo(calendar.startOfDay(for: currentDate), anchor: .top)
                hasScrolledToToday = true
            }
        }

    }
}
