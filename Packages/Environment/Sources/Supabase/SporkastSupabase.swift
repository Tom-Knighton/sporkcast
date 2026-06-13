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
        supabaseURL: URL(string: "https://db.sporkast.dev.tomk.online")!,
        supabaseKey: "sb_publishable_tyZO5jlR3XGvNuNHGOKDpe_Xms05kQF",
        options: SupabaseClientOptions(
            db: .init(schema: schema),
            auth: .init(
                storage: SporkastSupabaseKeychainLocalStorage(),
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
