//
//  InstallationId.swift
//  Environment
//
//  Created by Tom Knighton on 12/04/2026.
//


import Foundation
import Security

enum InstallationId {
    private static let service = "online.tomk.sporkast"
    private static let account = "launchdarkly-installation-id"

    static func get() -> String {
        if let existing = read() {
            return existing
        }

        let id = UUID().uuidString
        save(id)
        return id
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard
            status == errSecSuccess,
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    private static func save(_ value: String) {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }
}
