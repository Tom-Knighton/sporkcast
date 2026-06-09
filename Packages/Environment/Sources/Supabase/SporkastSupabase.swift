//
//  SporkastSupabase.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Foundation
import Supabase

public enum SporkastSupabase {
    public static let schema = "sporkast-mobile"

    public static let client = SupabaseClient(
        supabaseURL: URL(string: "https://ihalkpqoocifcpqjhumz.supabase.co")!,
        supabaseKey: "sb_publishable_hhkKsHI7VMMFPH2k5fAxUA_n_gcV1MU",
        options: SupabaseClientOptions(
            db: .init(schema: schema),
            auth: .init(
                storage: SporkastSupabaseKeychainLocalStorage(),
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
