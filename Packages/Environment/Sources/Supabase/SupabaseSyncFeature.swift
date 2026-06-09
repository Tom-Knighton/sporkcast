//
//  SupabaseSyncFeature.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Foundation

public enum SupabaseSyncFeature {
    private static let userDefaultsKey = "sporkast.supabaseSync.enabled"
    private static let environmentKey = "SPORKAST_SUPABASE_SYNC_ENABLED"

    public static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment[environmentKey] == "1" {
            return true
        }

        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    public static func setEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
    }
}
