//
//  RecipeTimersListView.swift
//  RecipeTimersList
//
//  Created by Tom Knighton on 05/10/2025.
//

import SwiftUI
import Environment
import API

public struct RecipeTimersListView: View {
    
    @Environment(RecipeTimerStore.self) private var alarmStore
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                ForEach(alarmStore.timers) { timer in
                    timerRow(timer)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await alarmStore.cancel(timer.id)
                                }
                            } label: { Label("Cancel", systemImage: "xmark") }
                        }
                }
                .frame(maxWidth: .infinity)
                .scenePadding(.horizontal)
                
                
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Timers")
        }
    }
    
    @ViewBuilder
    private func timerRow(_ timer: RecipeTimerRowModel) -> some View {
        HStack {
            VStack(alignment: .leading) {
                
                HStack {
                    timerDigits(timer)
                        .font(.largeTitle)
                    Text(timer.title)
                    
                    Spacer()
                    
                    CountdownProgressCircleView(alarm: timer)
                    Controls(row: timer)
                }

                if let description = timer.metadata.description {
                    Text(description)
                        .font(.caption)
                        .italic()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func timerDigits(_ timer: RecipeTimerRowModel) -> some View {
        switch timer.presentation.mode {
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
