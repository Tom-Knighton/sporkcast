//
//  OnboardingPage.swift
//  Settings
//
//  Created by Codex on 29/05/2026.
//

import Design
import SwiftUI

public struct OnboardingPage: View {
    @State private var selectedStepID = OnboardingStep.all[0].id
    @State private var isPaywallPresented = false

    private let complete: () -> Void

    private var selectedIndex: Int {
        OnboardingStep.all.firstIndex { $0.id == selectedStepID } ?? 0
    }

    private var selectedStep: OnboardingStep {
        OnboardingStep.all[selectedIndex]
    }

    private var isLastStep: Bool {
        selectedIndex == OnboardingStep.all.count - 1
    }

    public init(complete: @escaping () -> Void) {
        self.complete = complete
    }

    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()

            TabView(selection: $selectedStepID) {
                ForEach(OnboardingStep.all) { step in
                    OnboardingSlideView(step: step)
                        .tag(step.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                OnboardingControlsView(
                    selectedIndex: selectedIndex,
                    totalSteps: OnboardingStep.all.count,
                    isLastStep: isLastStep,
                    showsProCTA: selectedStep.showsProCTA,
                    next: next,
                    finish: complete,
                    showPro: showPro
                )
            }
        }
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView()
        }
        .interactiveDismissDisabled()
    }

    private func next() {
        guard !isLastStep else {
            complete()
            return
        }

        withAnimation(.snappy) {
            selectedStepID = OnboardingStep.all[selectedIndex + 1].id
        }
    }

    private func showPro() {
        isPaywallPresented = true
    }
}

#Preview {
    OnboardingPage {}
}
