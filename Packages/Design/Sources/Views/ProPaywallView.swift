//
//  ProPaywallView.swift
//  Design
//
//  Created by Tom Knighton on 20/05/2026.
//

import Environment
import RevenueCat
import RevenueCatUI
import SwiftUI

public struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.proAccess) private var proAccess
    @Environment(\.flagKit) private var flagKit

    @State private var completion: ProPaywallCompletion?
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()

            NavigationStack {
                if let completion {
                    ScrollView {
                        ProThankYouView(completion: completion, done: dismiss.callAsFunction)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.layer1.ignoresSafeArea())
                } else {
                    revenueCatPaywall
                }
            }
            .navigationTitle(completion == nil ? "Sporkast Pro" : "Thank You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(completion == nil ? "Close" : "Done", action: dismiss.callAsFunction)
                }
            }
        }
        .task {
            await proAccess.refresh()
        }
        .alert("Sporkast Pro", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private var revenueCatPaywall: some View {
        PaywallView(displayCloseButton: false)
            .onPurchaseCompleted { _ in
                complete(.purchase)
            }
            .onRestoreCompleted { _ in
                complete(.restore)
            }
    }

    private func complete(_ completion: ProPaywallCompletion) {
        Task {
            await proAccess.refresh()
            flagKit.updateSubscriptionTier(proAccess.subscriptionTier)
            await MainActor.run {
                presentCompletionOrError(completion)
            }
        }
    }

    private func presentCompletionOrError(_ completion: ProPaywallCompletion) {
        if proAccess.hasProAccess {
            withAnimation(.spring(duration: 0.45)) {
                self.completion = completion
            }
            return
        }

        if let message = proAccess.errorMessage {
            errorMessage = message
            isErrorPresented = true
        } else if completion == .restore {
            errorMessage = "No active Sporkast Pro purchase was found for this Apple ID."
            isErrorPresented = true
        }
    }
}

private enum ProPaywallCompletion {
    case purchase
    case restore

    var title: String {
        switch self {
        case .purchase: return "Welcome to Sporkast Pro"
        case .restore: return "Sporkast Pro Restored"
        }
    }

    var message: String {
        switch self {
        case .purchase:
            return "Thanks for supporting Sporkast. Folders, subfolders, tags, and pro search are ready on this device."
        case .restore:
            return "Your Pro access is active again. Folders, subfolders, tags, and pro search are ready on this device."
        }
    }
}

private struct ProThankYouView: View {
    let completion: ProPaywallCompletion
    let done: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ConfettiBurstView()
                .frame(height: 280)
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Spacer(minLength: 84)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 104, height: 104)
                    .glassEffect(.regular.tint(.green.opacity(0.16)), in: .circle)

                VStack(spacing: 10) {
                    Text(completion.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(completion.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: done) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

private struct ConfettiBurstView: View {
    @State private var isExpanded = false

    private let pieces: [ConfettiPiece] = (0..<42).map { index in
        ConfettiPiece(index: index)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: piece.cornerRadius)
                        .fill(piece.color)
                        .frame(width: piece.size.width, height: piece.size.height)
                        .rotationEffect(.degrees(isExpanded ? piece.rotation : 0))
                        .offset(
                            x: isExpanded ? piece.finalX(in: proxy.size.width) : 0,
                            y: isExpanded ? piece.finalY(in: proxy.size.height) : 0
                        )
                        .opacity(isExpanded ? 0 : 1)
                        .animation(
                            .easeOut(duration: piece.duration).delay(piece.delay),
                            value: isExpanded
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                isExpanded = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isExpanded = true
                }
            }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let angle: Double
    let distance: Double
    let delay: Double
    let duration: Double
    let rotation: Double
    let size: CGSize
    let color: Color
    let cornerRadius: CGFloat

    init(index: Int) {
        id = index
        angle = Double(index) * 137.5
        distance = 84 + Double((index * 29) % 128)
        delay = Double(index % 7) * 0.025
        duration = 1.1 + Double(index % 5) * 0.12
        rotation = Double((index * 47) % 360)
        size = CGSize(width: 7 + CGFloat(index % 4) * 2, height: 12 + CGFloat(index % 3) * 4)
        cornerRadius = CGFloat(index % 2)

        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        color = palette[index % palette.count]
    }

    func finalX(in width: CGFloat) -> CGFloat {
        cos(angle * .pi / 180) * distance
    }

    func finalY(in height: CGFloat) -> CGFloat {
        sin(angle * .pi / 180) * distance + 32
    }
}
