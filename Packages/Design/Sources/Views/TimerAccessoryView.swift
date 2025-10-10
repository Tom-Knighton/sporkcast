//
//  TimerAccessoryView.swift
//  Design
//
//  Created by Tom Knighton on 28/09/2025.
//

import SwiftUI
import AlarmKit
import Environment
import Observation

public struct TimerAccessoryView: View {
    
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(RecipeTimerStore.self) private var alarmStore
    let firstAlarm: RecipeTimerRowModel
    let totalAlarms: Int
    
    public init(first: RecipeTimerRowModel, totalAlarms: Int) {
        firstAlarm = first
        self.totalAlarms = totalAlarms
    }
    
    public var body: some View {
        HStack {
            HStack(spacing: 0) {
                CountdownProgressCircleView(alarm: firstAlarm)
                    .id(firstAlarm.id)
                CountdownProgressView(alarm: firstAlarm)
                    .id(firstAlarm.id)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(.secondary)
                    .frame(width: 30, height: 30)
                Text("\(totalAlarms)")
                    .id(totalAlarms)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: totalAlarms)
            }
            .id(totalAlarms)
            
            Button(action: {
                self.appRouter.presentSheet(.timersView)
            }) {
                Image(systemName: "chevron.right.circle.fill")
            }
            .badge(alarmStore.timers.count)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture {
            self.appRouter.presentSheet(.timersView)
        }
    }
}

struct CountdownTextView: View {
    let state: AlarmPresentationState
    
    var body: some View {
        if case let .countdown(countdown) = state.mode {
            Text(timerInterval: Date.now ... countdown.fireDate)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

struct CountdownProgressCircleView: View {
    @Bindable var alarm: RecipeTimerRowModel
    
    var body: some View {
        switch alarm.presentation.mode {
        case .countdown(let total, let previouslyElapsed, let startDate):
            TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
                let elapsed = max(0, min(total, previouslyElapsed + context.date.timeIntervalSince(startDate)))
                let progress = total > 0 ? elapsed / total : 1
                Gauge(value: 1 - progress) { EmptyView() } currentValueLabel: {
                    Image(systemName: "timer")
                        .tint(Color(hex: alarm.metadata.colorHex))
                        .padding()
                        .scaleEffect(0.75)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .scaleEffect(0.5)
                .tint(Color(hex: alarm.metadata.colorHex))
            }
        case let .paused(total: total, previouslyElapsed: prev):
            let progress = total > 0 ? prev / total : 1
            Gauge(value: 1 - progress) { EmptyView() } currentValueLabel: {
                Image(systemName: "timer")
                    .tint(Color(hex: alarm.metadata.colorHex))
                    .padding()
                    .scaleEffect(0.75)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .scaleEffect(0.5)
            .tint(Color(hex: alarm.metadata.colorHex))
        case .alerting:
            Image(systemName: "alarm.waves.left.and.right")
                .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
        case .scheduled(_):
            Image(systemName: "alarm")
        }
        
    }
}

struct CountdownProgressView: View {
    @Bindable var alarm: RecipeTimerRowModel
    
    var body: some View {
        
        switch alarm.presentation.mode {
        case .countdown(let total, let previouslyElapsed, let startDate):
            let remaining = max(0, total - previouslyElapsed)
            Text(timerInterval: startDate ... startDate.addingTimeInterval(remaining),
                 countsDown: true,
                 showsHours: true)
            
        case .paused(let total, let prev):
            let remaining = max(0, total - prev)
            let duration = Duration.seconds(remaining)
            Text(duration, format: .time(pattern: remaining >= 3600 ? .hourMinuteSecond : .minuteSecond))
            
        case .alerting:
            Text("00:00")
            
        case .scheduled(let date):
            Text(date, style: .time)
        }
    }
}


public struct TimersView: View {
    
    @Environment(RecipeTimerStore.self) private var alarmStore
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(alarmStore.timers) { row in
                        TimerRow(row: row)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await alarmStore.cancel(row.id) }
                                } label: { Label("Cancel", systemImage: "xmark") }
                            }
                    }
                }
                .scenePadding(.horizontal)
            }
            .navigationTitle("Timers")
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

struct TimerRow: View {
    let row: RecipeTimerRowModel
    @State private var now = Date()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(row.title).font(.headline)
                TimerDigitsView(presentation: row.presentation)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
            }
            Spacer()
            Controls(row: row)
            Button(role: .destructive) {
                Task { await RecipeTimerStore.shared.cancel(row.id) }
            } label: { Image(systemName: "xmark") }
        }
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private func Controls(row: RecipeTimerRowModel) -> some View {
        switch row.presentation.mode {
        case .countdown:
            Button {
                Task { await RecipeTimerStore.shared.pause(row.id) }
            } label: { Image(systemName: "pause.fill") }
            
        case .paused:
            Button {
                Task { await RecipeTimerStore.shared.resume(row.id) }
            } label: { Image(systemName: "play.fill") }
            
        case .alerting:
            EmptyView()
            
        case .scheduled:
            EmptyView()
        }
    }
}

struct TimerDigitsView: View {
    let presentation: RecipeTimerPresentation
    
    var body: some View {
        switch presentation.mode {
        case .countdown(let total, let previouslyElapsed, let startDate):
            let remaining = max(0, total - previouslyElapsed)
            Text(timerInterval: startDate ... startDate.addingTimeInterval(remaining),
                 countsDown: true,
                 showsHours: true)
            
        case .paused(let total, let prev):
            let remaining = max(0, total - prev)
            let duration = Duration.seconds(remaining)
            Text(duration, format: .time(pattern: remaining >= 3600 ? .hourMinuteSecond : .minuteSecond))
            
        case .alerting:
            Text("00:00")
            
        case .scheduled(let date):
            Text(date, style: .time)
        }
    }
}
