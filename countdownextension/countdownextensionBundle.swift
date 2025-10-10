//
//  countdownextensionBundle.swift
//  countdownextension
//
//  Created by Tom Knighton on 27/09/2025.
//

import WidgetKit
import SwiftUI
import AlarmKit
import Environment
import AppIntents
import ActivityKit

@main
struct countdownextensionBundle: WidgetBundle {
    var body: some Widget {
        CountdownTimerLiveActivity()
    }
}

struct CountdownTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<RecipeTimerMetadata>.self) { context in
            HStack {
                Group {
                    if case .countdown = context.state.mode {
                        Button(intent: PauseTimerIntent(alarmID: context.state.alarmID)) {
                            Image(systemName: "pause.fill")
                        }
                        .tint(context.attributes.tintColor)
                    }
                    
                    if case .paused = context.state.mode {
                        Button(intent: ResumeTimerIntent(alarmID: context.state.alarmID)) {
                            Image(systemName: "play.fill")
                        }
                        .tint(context.attributes.tintColor)
                    }
                    
                    Button(intent: StopTimerIntent(alarmID: context.state.alarmID)) {
                        Image(systemName: "xmark")
                    }
                    .tint(.gray)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .font(.title)
               
                
                Spacer()
                
                CountdownTextView(state: context.state, font: UIFont.preferredFont(forTextStyle: .largeTitle))
                    .font(.largeTitle)
                    .padding()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Group {
                            if case .countdown = context.state.mode {
                                Button(intent: PauseTimerIntent(alarmID: context.state.alarmID)) {
                                    Image(systemName: "pause.fill")
                                }
                                .tint(context.attributes.tintColor)
                            }
                            
                            if case .paused = context.state.mode {
                                Button(intent: ResumeTimerIntent(alarmID: context.state.alarmID)) {
                                    Image(systemName: "play.fill")
                                }
                                .tint(context.attributes.tintColor)
                            }
                            
                            Button(intent: StopTimerIntent(alarmID: context.state.alarmID)) {
                                Image(systemName: "xmark")
                            }
                            .tint(.gray)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .font(.title)
                    }
                    .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.metadata?.description ?? context.attributes.metadata?.title ?? "Timer")
                        .padding(.all, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        CountdownTextView(state: context.state, font: UIFont.preferredFont(forTextStyle: .title1))
                    }
                    .frame(maxHeight: .infinity)
                }
            } compactLeading: {
                CountdownProgressView(state: context.state, attributes: context.attributes)
            } compactTrailing: {
                CountdownTextView(state: context.state, font: UIFont.preferredFont(forTextStyle: .body))
            } minimal: {
                CountdownProgressView(state: context.state, attributes: context.attributes)
            }
        }
    }
}

struct CountdownTextView: View {
    let state: AlarmPresentationState
    
    let font: UIFont
    
    var body: some View {
        switch state.mode {
        case let .countdown(countdown):
            TextTimer(countdown.fireDate, font: font)
                .monospacedDigit()
                .lineLimit(1)
        case let .paused(paused):
            let remaining = paused.totalCountdownDuration - paused.previouslyElapsedDuration
            let duration = Duration.seconds(remaining)
            Text(duration, format: .time(pattern: remaining >= 3600 ? .hourMinuteSecond : .minuteSecond))
        case .alert:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

struct CountdownProgressView: View {
    let state: AlarmPresentationState
    let attributes: AlarmAttributes<RecipeTimerMetadata>
    
    var body: some View {
        switch state.mode {
        case let .countdown(countdown):
            let remaining = countdown.totalCountdownDuration - countdown.previouslyElapsedDuration
            
            ProgressView(
                timerInterval: countdown.startDate...countdown.startDate.addingTimeInterval(remaining),
                countsDown: true,
                label: {
                    Image(systemName: "timer")
                },
                currentValueLabel: {}
            )
            .progressViewStyle(.circular)
            .tint(attributes.tintColor)
            
        case .alert:
            Image(systemName: "alarm.waves.left.and.right")
                .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
        case .paused:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

struct TextTimer: View {
    // Return the largest width string for a time interval
    private static func maxStringFor(_ time: TimeInterval) -> String {
        if time < 600 { // 9:99
            return "0:00"
        }
        
        if time < 3600 { // 59:59
            return "00:00"
        }
        
        if time < 36000 { // 9:59:59
            return "0:00:00"
        }
        
        return "00:00:00"// 99:59:59
    }
    
    init(_ date: Date, font: UIFont, width: CGFloat? = nil) {
        self.date = date
        self.font = font
        if let width {
            self.width = width
        } else {
            let fontAttributes = [NSAttributedString.Key.font: font]
            let time = date.timeIntervalSinceNow
            let maxString = Self.maxStringFor(time)
            self.width = (maxString as NSString).size(withAttributes: fontAttributes).width
        }
    }
    
    let date: Date
    let font: UIFont
    let width: CGFloat
    var body: some View {
        Text(timerInterval: Date.now...date)
            .font(Font(font))
            .frame(width: width > 0 ? width : nil)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}
