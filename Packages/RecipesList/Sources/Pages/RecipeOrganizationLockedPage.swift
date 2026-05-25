//
//  RecipeOrganizationLockedPage.swift
//  RecipesList
//

import Design
import SwiftUI

struct RecipeOrganizationLockedPage: View {
    @State private var isProPaywallPresented = false

    var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    features
                    unlockButton
                }
                .padding(18)
            }
        }
        .navigationTitle("Folders & Tags")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isProPaywallPresented) {
            ProPaywallView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Organize your cookbook")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Text("Group recipes into folders, mark them with tags, and get back to the right dinner faster.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RecipeOrganizationLockedGlassSurface())
    }

    private var features: some View {
        VStack(spacing: 12) {
            RecipeOrganizationLockedFeatureRow(
                title: "Folders for every kind of cooking",
                subtitle: "Keep weeknights, baking, meal prep, and dinner-party recipes separate.",
                systemImage: "folder"
            )

            RecipeOrganizationLockedFeatureRow(
                title: "Tags that cut across folders",
                subtitle: "Mark recipes by cuisine, diet, season, effort, or who loves them most.",
                systemImage: "tag"
            )

            RecipeOrganizationLockedFeatureRow(
                title: "Quick filtering when it matters",
                subtitle: "Find the recipe you meant to cook without scrolling through everything.",
                systemImage: "line.3.horizontal.decrease.circle"
            )

            RecipeOrganizationLockedFeatureRow(
                title: "More Pro tools for planning",
                subtitle: "Also includes social imports, discovery, weather, mealplan widgets, and Calendar sync.",
                systemImage: "sparkles"
            )
        }
    }

    private var unlockButton: some View {
        Button("Unlock Folders & Tags", systemImage: "sparkles") {
            isProPaywallPresented = true
        }
        .buttonStyle(.glassProminent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecipeOrganizationLockedFeatureRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 30)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RecipeOrganizationLockedGlassSurface())
    }
}

private struct RecipeOrganizationLockedGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}
