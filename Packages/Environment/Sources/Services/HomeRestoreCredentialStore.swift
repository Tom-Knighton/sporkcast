//
//  HomeRestoreCredentialStore.swift
//  Environment
//
//  Created by Tom Knighton on 14/06/2026.
//

import Foundation
import Security

public struct HomeRestoreCredential: Codable, Equatable, Sendable {
    public let homeId: UUID
    public let token: String

    public init(homeId: UUID, token: String) {
        self.homeId = homeId
        self.token = token
    }
}

public enum HomeRestoreCredentialStore {
    private static let credentialKey = "sporkast.homeRestoreCredential.v1"

    public static func credential() -> HomeRestoreCredential? {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()

        guard
            let data = store.data(forKey: credentialKey),
            let credential = try? JSONDecoder().decode(HomeRestoreCredential.self, from: data)
        else {
            return nil
        }

        return credential
    }

    public static func credential(for homeId: UUID) -> HomeRestoreCredential {
        if let existing = credential(), existing.homeId == homeId {
            return existing
        }

        let credential = HomeRestoreCredential(homeId: homeId, token: makeToken())
        save(credential)
        return credential
    }

    public static func save(_ credential: HomeRestoreCredential) {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: credentialKey)
        store.synchronize()
    }

    public static func clear(homeId: UUID? = nil) {
        guard homeId == nil || credential()?.homeId == homeId else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.removeObject(forKey: credentialKey)
        store.synchronize()
    }

    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }

        return UUID().uuidString + UUID().uuidString
    }
}
