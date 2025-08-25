//
//  sporkcastApp.swift
//  sporkcast
//
//  Created by Tom Knighton on 22/08/2025.
//

import SwiftUI
import Recipe
import Design
import API

@main
struct sporkcastApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RecipePage()
            }
            .environment(\.networkClient, APIClient(host: "https://api.dev.recipe.tomk.online/"))
        }
    }
}
