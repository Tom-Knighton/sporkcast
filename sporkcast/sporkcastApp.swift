//
//  sporkcastApp.swift
//  sporkcast
//
//  Created by Tom Knighton on 22/08/2025.
//

import SwiftUI
import API
import SwiftData

@main
struct SporkcastApp: App {
    var body: some Scene {
        WindowGroup {
            AppContent()
                .modelContainer(V1Models.sharedContainer!)
        }
    }
}
