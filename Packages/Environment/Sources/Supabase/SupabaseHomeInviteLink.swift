//
//  SupabaseHomeInviteLink.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Foundation

public struct SupabaseHomeInviteLink: Identifiable, Sendable, Equatable {
    public static let host = "sporkast.tom-knighton.com"

    public let token: String

    public var id: String { token }

    public init(token: String) {
        self.token = token
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/join/\(token)"
        return components.url ?? URL(string: "https://\(Self.host)/join/\(token)")!
    }
}
