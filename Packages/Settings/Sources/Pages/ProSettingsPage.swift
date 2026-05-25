//
//  ProSettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 20/05/2026.
//

import Design
import Environment
import SwiftUI

public struct ProSettingsPage: View {
    @Environment(\.proAccess) private var proAccess
    @Environment(\.flagKit) private var flagKit

    @State private var isPaywallPresented = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    public init() {}

    public var body: some View {
        List {
            Section {
                statusRow
            } header: {
                Text("Subscription")
            } footer: {
                Text("Sporkast Pro is evaluated per person, so members of the same Home can have different access.")
            }

            Section {
                Button(action: { isPaywallPresented = true }) {
                    Label(proAccess.hasProAccess ? "View Plans" : "Get Sporkast Pro", systemImage: "sparkles")
                }

                Button(action: restorePurchases) {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
                .disabled(proAccess.isLoading)
            }

            Section("Included") {
                Label("Nested recipe folders", systemImage: "folder.fill.badge.plus")
                Label("Recipe tags and suggestions", systemImage: "tag.fill")
                Label("Search by folder and tag names", systemImage: "magnifyingglass")
                Label("Manage organization from recipe editing", systemImage: "slider.horizontal.3")
                Label("Social recipe imports from Reels and TikToks", systemImage: "sparkles.tv")
                Label("Recipe discovery from trusted sources", systemImage: "sparkles.rectangle.stack.fill")
                Label("Weather forecasts in meal planning", systemImage: "cloud.sun.fill")
                Label("Mealplan widgets", systemImage: "rectangle.inset.filled.and.person.filled")
                Label("Mealplans in iCloud Calendar", systemImage: "calendar.badge.checkmark")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sporkast Pro")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .task {
            await proAccess.refresh()
            flagKit.updateSubscriptionTier(proAccess.subscriptionTier)
        }
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallView()
        }
        .alert("Sporkast Pro", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: proAccess.hasProAccess ? "checkmark.seal.fill" : "lock.fill")
                .foregroundStyle(proAccess.hasProAccess ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(proAccess.hasProAccess ? "Active" : "Not Active")
                    .font(.headline)

                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if proAccess.isLoading {
                ProgressView()
            }
        }
    }

    private var statusSubtitle: String {
        switch proAccess.subscriptionTier {
        case "pro_monthly": return "Monthly plan"
        case "pro_yearly": return "Yearly plan"
        case "pro_lifetime": return "Lifetime plan"
        case "pro": return "Pro access"
        default: return "Unlock organization, imports, discovery, weather, widgets, and Calendar sync"
        }
    }

    private func restorePurchases() {
        Task {
            await proAccess.restorePurchases()
            flagKit.updateSubscriptionTier(proAccess.subscriptionTier)

            if let message = proAccess.errorMessage {
                errorMessage = message
                isErrorPresented = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProSettingsPage()
    }
    .environment(\.proAccess, MockProAccessService())
    .environment(\.flagKit, MockFlagService())
}
