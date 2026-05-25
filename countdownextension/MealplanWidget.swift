//
//  MealplanWidget.swift
//  countdownextension
//
//  Created by Tom Knighton on 25/05/2026.
//

import AppIntents
import Environment
import SwiftUI
import WidgetKit

struct MealplanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MealplanWidgetSnapshotStore.widgetKind, provider: MealplanTimelineProvider()) { entry in
            MealplanWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    MealplanWidgetBackground()
                }
                .widgetURL(URL(string: "sporkcast://mealplan"))
        }
        .configurationDisplayName("Mealplan")
        .description("See upcoming meals from your Sporkast mealplan.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct MealplanTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: MealplanWidgetSnapshot
    let selectedDayOffset: Int
    let relevance: TimelineEntryRelevance?
}

struct MealplanTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealplanTimelineEntry {
        MealplanTimelineEntry(
            date: .now,
            snapshot: .preview(hasProAccess: true),
            selectedDayOffset: 0,
            relevance: TimelineEntryRelevance(score: 70, duration: 60 * 60 * 4)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MealplanTimelineEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealplanTimelineEntry>) -> Void) {
        let current = entry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: current.date) ?? current.date.addingTimeInterval(1800)
        completion(Timeline(entries: [current], policy: .after(nextRefresh)))
    }

    private func entry() -> MealplanTimelineEntry {
        let now = Date()
        let snapshot = MealplanWidgetSnapshotStore.load(now: now)
        let selectedDayOffset = MealplanWidgetSnapshotStore.selectedDayOffset
        let selectedDay = snapshot.days[safe: selectedDayOffset]
        let score: Float = selectedDay?.entries.isEmpty == false ? 85 : 45

        return MealplanTimelineEntry(
            date: now,
            snapshot: snapshot,
            selectedDayOffset: selectedDayOffset,
            relevance: TimelineEntryRelevance(score: score, duration: 60 * 60 * 3)
        )
    }
}

private struct MealplanWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MealplanTimelineEntry

    private var selectedDay: MealplanWidgetDay? {
        entry.snapshot.days[safe: entry.selectedDayOffset]
    }

    var body: some View {
        switch family {
        case .systemSmall:
            MealplanSmallWidgetContent(
                day: selectedDay,
                canPageBackward: entry.selectedDayOffset > 0,
                canPageForward: entry.selectedDayOffset < entry.snapshot.days.count - 1,
                hasProAccess: entry.snapshot.hasProAccess
            )
        case .systemMedium:
            MealplanMediumWidgetContent(
                days: entry.snapshot.days,
                selectedDayOffset: entry.selectedDayOffset,
                hasProAccess: entry.snapshot.hasProAccess
            )
        case .systemLarge:
            MealplanLargeWidgetContent(
                days: entry.snapshot.days,
                selectedDayOffset: entry.selectedDayOffset,
                hasProAccess: entry.snapshot.hasProAccess
            )
        case .accessoryInline:
            MealplanAccessoryInlineContent(day: selectedDay, hasProAccess: entry.snapshot.hasProAccess)
        case .accessoryRectangular:
            MealplanAccessoryRectangularContent(day: selectedDay, hasProAccess: entry.snapshot.hasProAccess)
        default:
            MealplanSmallWidgetContent(
                day: selectedDay,
                canPageBackward: entry.selectedDayOffset > 0,
                canPageForward: entry.selectedDayOffset < entry.snapshot.days.count - 1,
                hasProAccess: entry.snapshot.hasProAccess
            )
        }
    }
}

private struct MealplanSmallWidgetContent: View {
    let day: MealplanWidgetDay?
    let canPageBackward: Bool
    let canPageForward: Bool
    let hasProAccess: Bool

    var body: some View {
        MealplanLockingContent(hasProAccess: hasProAccess) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    MealplanWidgetHeader(day: day, compact: true)
                    Spacer(minLength: 4)
                    MealplanPagingControls(
                        canPageBackward: canPageBackward,
                        canPageForward: canPageForward,
                        compact: true
                    )
                }

                if let firstMeal = day?.entries.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(firstMeal.title)
                            .font(.headline)
                            .lineLimit(4)
                            .minimumScaleFactor(0.68)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(day?.entries.count == 1 ? (firstMeal.detail ?? "Planned meal") : "\(day?.entries.count ?? 0) meals planned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    MealplanNoMealsView(compact: true)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
        }
    }
}

private struct MealplanMediumWidgetContent: View {
    let days: [MealplanWidgetDay]
    let selectedDayOffset: Int
    let hasProAccess: Bool

    private var selectedDay: MealplanWidgetDay? {
        days[safe: selectedDayOffset]
    }

    var body: some View {
        MealplanLockingContent(hasProAccess: hasProAccess) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    MealplanWidgetHeader(day: selectedDay, compact: false)
                    Spacer()
                    MealplanPagingControls(
                        canPageBackward: selectedDayOffset > 0,
                        canPageForward: selectedDayOffset < days.count - 1,
                        compact: false
                    )
                }

                if let selectedDay, selectedDay.entries.isEmpty == false {
                    VStack(spacing: 7) {
                        ForEach(selectedDay.entries.prefix(3)) { meal in
                            MealplanMealRow(meal: meal)
                        }
                    }
                } else {
                    MealplanNoMealsView(compact: false)
                }
            }
            .padding(12)
        }
    }
}

private struct MealplanLargeWidgetContent: View {
    let days: [MealplanWidgetDay]
    let selectedDayOffset: Int
    let hasProAccess: Bool

    private var visibleDays: ArraySlice<MealplanWidgetDay> {
        days.prefix(5)
    }

    var body: some View {
        MealplanLockingContent(hasProAccess: hasProAccess) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mealplan")
                            .font(.title3)
                            .bold()
                        Text("Next \(min(days.count, 5)) days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(visibleDays) { day in
                        MealplanDayStrip(day: day, isSelected: isHighlighted(day))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private func isHighlighted(_ day: MealplanWidgetDay) -> Bool {
        Calendar.current.isDateInToday(day.date)
    }
}

private struct MealplanAccessoryInlineContent: View {
    let day: MealplanWidgetDay?
    let hasProAccess: Bool

    var body: some View {
        if hasProAccess {
            Label(accessoryText, systemImage: "fork.knife")
        } else {
            Label("Pro mealplan widget", systemImage: "lock.fill")
        }
    }

    private var accessoryText: String {
        guard let day else { return "No meals planned" }
        guard let first = day.entries.first else { return "No meals today" }
        return day.entries.count == 1 ? first.title : "\(first.title) +\(day.entries.count - 1)"
    }
}

private struct MealplanAccessoryRectangularContent: View {
    let day: MealplanWidgetDay?
    let hasProAccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if hasProAccess {
                if let first = day?.entries.first {
                    Text(first.title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Label(day?.entries.count == 1 ? dateText : "\(day?.entries.count ?? 0) meals planned", systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No meals planned")
                        .font(.headline)
                    Label(dateText, systemImage: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Pro mealplan widget")
                    .font(.body)
                    .lineLimit(2)
            }
        }
    }

    private var dateText: String {
        guard let day else { return "Mealplan" }
        if Calendar.current.isDateInToday(day.date) { return "Today" }
        if Calendar.current.isDateInTomorrow(day.date) { return "Tomorrow" }
        return day.date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct MealplanLockingContent<Content: View>: View {
    let hasProAccess: Bool
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            if hasProAccess {
                content
            } else {
                MealplanLockedView()
                    .padding(16)
            }
        }
    }
}

private struct MealplanLockedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Pro mealplan widget")
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text("Upgrade to show mealplans here, plus unlock Calendar sync, weather, discovery, social imports, and folders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MealplanWidgetHeader: View {
    let day: MealplanWidgetDay?
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayTitle)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
            Text(dayName)
                .font(compact ? .title3 : .title2)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var dayTitle: String {
        guard let day else { return "Upcoming" }
        if Calendar.current.isDateInToday(day.date) { return "Today" }
        if Calendar.current.isDateInTomorrow(day.date) { return "Tomorrow" }
        return day.date.formatted(.dateTime.weekday(.wide))
    }

    private var dayName: String {
        guard let day else { return "Mealplan" }
        return day.date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct MealplanPagingControls: View {
    let canPageBackward: Bool
    let canPageForward: Bool
    let compact: Bool

    var body: some View {
        if compact {
            controls
                .buttonStyle(.plain)
                .frame(minHeight: 20)
        } else {
            controls
                .buttonStyle(.bordered)
        }
    }

    private var controls: some View {
        HStack(spacing: compact ? 3 : 8) {
            Button(intent: MealplanWidgetPageIntent(direction: .previous)) {
                Label("Previous day", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .disabled(!canPageBackward)

            Button(intent: MealplanWidgetPageIntent(direction: .next)) {
                Label("Next day", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .disabled(!canPageForward)
        }
        .font(.caption.bold())
        .controlSize(.small)
    }
}

private struct MealplanMealRow: View {
    let meal: MealplanWidgetMeal

    var body: some View {
        HStack(spacing: 8) {
            MealAccent(meal: meal)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title)
                    .font(.headline)
                    .lineLimit(1)
                if let detail = meal.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.28), in: .rect(cornerRadius: 8))
    }
}

private struct MealplanDayStrip: View {
    let day: MealplanWidgetDay
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 1) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(.headline)
                    .bold()
            }
            .frame(width: 44)

            if let meal = day.entries.first {
                MealAccent(meal: meal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(day.entries.count == 1 ? (meal.detail ?? "Planned meal") : "\(day.entries.count) meals planned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("No meals planned")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(isSelected ? .white.opacity(0.34) : .white.opacity(0.18), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.orange.opacity(0.75) : Color.clear, lineWidth: 1)
        }
    }
}

private struct MealplanNoMealsView: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Text("No meals planned")
                .font(compact ? .headline : .title3)
                .bold()
                .lineLimit(1)
            Text("Your day is open.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MealBadge: View {
    let meal: MealplanWidgetMeal

    var body: some View {
        Label(meal.kind == .recipe ? "Recipe" : "Note", systemImage: meal.kind == .recipe ? "fork.knife" : "note.text")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

private struct MealAccent: View {
    let meal: MealplanWidgetMeal

    var body: some View {
        Circle()
            .fill(meal.accentHex.flatMap(Color.init(hex:)) ?? (meal.kind == .recipe ? Color.orange : Color.blue))
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.65), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct MealplanWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.94, blue: 0.84),
                Color(red: 0.86, green: 0.95, blue: 0.9),
                Color(red: 0.96, green: 0.88, blue: 0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension MealplanWidgetSnapshot {
    static func preview(hasProAccess: Bool) -> MealplanWidgetSnapshot {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        return MealplanWidgetSnapshot(
            generatedAt: .now,
            hasProAccess: hasProAccess,
            days: [
                MealplanWidgetDay(
                    date: today,
                    dateKey: "preview-today",
                    entries: [
                        MealplanWidgetMeal(id: UUID(), kind: .recipe, title: "Miso mushroom noodles", detail: "25 min", accentHex: "D97941"),
                        MealplanWidgetMeal(id: UUID(), kind: .note, title: "Use the pak choi", detail: "Note", accentHex: nil)
                    ]
                ),
                MealplanWidgetDay(
                    date: tomorrow,
                    dateKey: "preview-tomorrow",
                    entries: [
                        MealplanWidgetMeal(id: UUID(), kind: .recipe, title: "Roast squash tacos", detail: "40 min", accentHex: "5C9E72")
                    ]
                )
            ]
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        guard cleaned.count == 6,
              let value = Int(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}

#Preview(as: .systemLarge) {
    MealplanWidget()
} timeline: {
    MealplanTimelineEntry(
        date: .now,
        snapshot: .preview(hasProAccess: true),
        selectedDayOffset: 0,
        relevance: nil
    )
    MealplanTimelineEntry(
        date: .now,
        snapshot: .preview(hasProAccess: false),
        selectedDayOffset: 0,
        relevance: nil
    )
}
