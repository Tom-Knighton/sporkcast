//
//  PreviewEnv.swift
//  Design
//
//  Created by Tom Knighton on 25/08/2025.
//

import API
import SwiftUI

@MainActor
public extension View {
    
    func withPreviewEnvs() -> some View {
        return self
            .environment(\.networkClient, MockClient())
    }
}
