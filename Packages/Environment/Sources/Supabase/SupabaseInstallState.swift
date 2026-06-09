//
//  SupabaseInstallState.swift
//  Environment
//
//  Created by Tom Knighton on 09/06/2026.
//

import Foundation

public enum SupabaseInstallState {
    private static let installationMarkerKey = "sporkast.supabase.installMarker.v1"

    public static func clearPersistedSessionAfterFreshInstallIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: installationMarkerKey) == nil else { return }

        do {
            try SporkastSupabaseKeychainLocalStorage.removeAll()
            RecipeDebugDiagnostics.logAppEvent("supabase cleared persisted auth after fresh install")
        } catch {
            RecipeDebugDiagnostics.logAppEvent("supabase auth clear after fresh install failed error=\(error)")
        }

        defaults.set(UUID().uuidString, forKey: installationMarkerKey)
    }
}
