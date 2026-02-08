//
//  SettingsPage.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftUI
import Design
import Environment
import API

public struct SettingsPage: View {
    
    @Environment(AppRouter.self) private var appRouter
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var repository = SettingsRepository()
    public init() {}
    
    public var body: some View {
        List {
            Section {
                NavigationLink(destination: GeneralSettingsPage()) {
                    Label("General", systemImage: "gearshape.fill")
                }
            }
            
            Section {
                Button(action: { appRouter.presentSheet(.householdSettings) }) {
                    NavigationLink(destination: EmptyView()) {
                        Label("Home", systemImage: "house.fill")
                    }
                }
            }
            
            #if DEBUG
            Section {
                Button(action: {
                    Task {
                        do {
                            try await repository.deleteAllData()
                        } catch {
                            print(error.localizedDescription)
                        }
                        
                        
                    }
                }) {
                    Text("Delete All DB")
                }
                Button(action: {
                    Task {
                        do {
                            let url = try await repository.exportDatabase()
                            exportURL = url
                            showShare = true
                        } catch {
                            print("Export failed: \(error)")
                        }
                    }
                }) {
                    Text("Export DB")
                }
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
    }
    
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let _ = PreviewSupport.preparePreviewDatabase()

    NavigationStack {
        SettingsPage()
    }
    .environment(AppRouter(initialTab: .settings))
    .environment(\.homeServices, HouseholdService.shared)
    .environment(\.appSettings, SettingsStore())
    .environment(\.cloudKit, MockCloudKitGate())
    .environment(\.networkClient, APIClient(host: "https://api.dev.sporkast.tomk.online/"))
}
