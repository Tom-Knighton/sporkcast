import SwiftUI
import Design
import Environment
import API

public struct SettingsPage: View {
    @State private var selection: SettingsDestination?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            NavigationStack {
                SettingsDetailView(selection: selection)
            }
            .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()

    SettingsPage()
        .environment(AppRouter(initialTab: .settings))
        .environment(\.homeServices, HouseholdService.shared)
        .environment(\.appSettings, SettingsStore())
        .environment(\.networkClient, APIClient(host: "https://api.dev.sporkast.tomk.online/"))
}
