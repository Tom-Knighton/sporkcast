//
//  RecipeImportStatusSheet.swift
//  RecipesList
//
//  Created by Tom Knighton on 26/03/2026.
//

import SwiftUI

public struct RecipeImportStatusSheet: View {

    let startedAt: Date
    let statusTitle: String?
    let statusSubtitle: String?
    let failureMessage: String?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        startedAt: Date,
        statusTitle: String? = nil,
        statusSubtitle: String? = nil,
        failureMessage: String?,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.startedAt = startedAt
        self.statusTitle = statusTitle
        self.statusSubtitle = statusSubtitle
        self.failureMessage = failureMessage
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 18) {
            if let failureMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("This recipe didn't import")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(failureMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                        .buttonStyle(.borderedProminent)

                    Button("Dismiss", role: .cancel, action: onDismiss)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            } else if let statusTitle {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.14))
                            .frame(width: 54, height: 54)

                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .accessibilityHidden(true)

                    ProgressView()
                        .controlSize(.large)
                        .accessibilityLabel("Recipe import in progress")

                    Text(statusTitle)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    if let statusSubtitle {
                        Text(statusSubtitle)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let stage = ImportStage(elapsed: context.date.timeIntervalSince(startedAt))

                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(stage.tintColor.opacity(0.16))
                                .frame(width: 54, height: 54)

                            Image(systemName: stage.symbolName)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(stage.tintColor)
                        }
                        .scaleEffect(stage == .wrappingUp && !reduceMotion ? 1.05 : 1.0)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.35),
                            value: stage
                        )
                        .accessibilityHidden(true)

                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(stage == .wrappingUp && !reduceMotion ? 1.1 : 1.0)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.4),
                                value: stage
                            )
                            .accessibilityLabel("Recipe import in progress")

                        Text(stage.title)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)

                        Text(stage.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.25),
                                value: stage
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: stage)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.12),
                            Color.yellow.opacity(0.07),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

private extension RecipeImportStatusSheet {

    enum ImportStage: Equatable {
        case connecting
        case parsing
        case structuring
        case wrappingUp

        init(elapsed: TimeInterval) {
            if elapsed < 3 {
                self = .connecting
            } else if elapsed < 8 {
                self = .parsing
            } else if elapsed < 16 {
                self = .structuring
            } else {
                self = .wrappingUp
            }
        }

        var title: String {
            switch self {
            case .connecting:
                "Warming up the kitchen"
            case .parsing:
                "Reading the recipe card"
            case .structuring:
                "Plating ingredients and steps"
            case .wrappingUp:
                "Adding the finishing garnish"
            }
        }

        var subtitle: String {
            switch self {
            case .connecting:
                "Fetching the page and getting everything ready."
            case .parsing:
                "Pulling out the title, timings, and method."
            case .structuring:
                "Organising it so it's ready in your recipe list."
            case .wrappingUp:
                "Almost there. Some websites take a little longer to simmer."
            }
        }

        var symbolName: String {
            switch self {
            case .connecting:
                "fork.knife"
            case .parsing:
                "text.magnifyingglass"
            case .structuring:
                "list.bullet.rectangle.portrait"
            case .wrappingUp:
                "checklist"
            }
        }

        var tintColor: Color {
            switch self {
            case .connecting:
                .orange
            case .parsing:
                .teal
            case .structuring:
                .mint
            case .wrappingUp:
                .green
            }
        }
    }
}

#Preview {
    VStack {
        
    }
    .sheet(isPresented: .constant(true)) {
        RecipeImportStatusSheet(startedAt: Date(), failureMessage: "") {
            
        } onDismiss: {
            
        }
        .interactiveDismissDisabled(true)
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.hidden)
    }
}
