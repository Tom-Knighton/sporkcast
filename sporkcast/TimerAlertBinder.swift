//
//  TimerAlertBinder.swift
//  sporkcast
//
//  Created by Tom Knighton on 10/10/2025.
//


import SwiftUI
import AlarmKit
import Environment

struct TimerAlertBinder: ViewModifier {
    @Bindable var alarmManager: RecipeTimerStore
    @State private var alerting: RecipeTimerRowModel?
    @State private var show = false

    func body(content: Content) -> some View {
        content
            .onChange(of: alarmManager.timers, initial: true) { _, newValue in
                if let first = newValue.first(where: { $0.alarmState == .alerting }) {
                    alerting = first
                    show = true
                }
            }
            .alert(alerting?.metadata.title ?? alerting?.title ?? "Timer", isPresented: $show) {
                Button("Stop Timer") {
                    Task {
                        if let id = alerting?.id {
                            await alarmManager.cancel(id)
                        }
                    }
                }
            } message: {
                Text(alerting?.metadata.description ?? "")
            }
    }
}

extension View {
    func bindTimerAlerts(_ store: RecipeTimerStore) -> some View {
        modifier(TimerAlertBinder(alarmManager: store))
    }
}
