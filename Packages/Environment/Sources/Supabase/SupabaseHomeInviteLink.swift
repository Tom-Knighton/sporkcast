//
//  SupabaseHomeInviteLink.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Foundation

public struct SupabaseHomeInviteLink: Identifiable, Sendable, Equatable {
    public let token: String

    public var id: String { token }

    public init(token: String) {
        self.token = token
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "sporkcast"
        components.host = "join-home"
        components.queryItems = [
            URLQueryItem(name: "token", value: token)
        ]
        return components.url ?? URL(string: "sporkcast://join-home?token=\(token)")!
    }
}
