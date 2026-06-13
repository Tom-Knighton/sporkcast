//
//  SporkastSupabaseKeychainLocalStorage.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Foundation
import Security
import Supabase

public struct SporkastSupabaseKeychainLocalStorage: AuthLocalStorage {
    public static let defaultService = "online.tomk.sporkcast.supabase"
    private let service: String

    public init(service: String = Self.defaultService) {
        self.service = service
    }

    public func store(key: String, value: Data) throws {
        try remove(key: key)

        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrSynchronizable: kCFBooleanTrue as Any,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: value
        ] as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainStorageError.storeFailed(status)
        }
    }

    public func retrieve(key: String) throws -> Data? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStorageError.retrieveFailed(status)
        }

        return item as? Data
    }

    public func remove(key: String) throws {
        let status = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ] as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStorageError.removeFailed(status)
        }
    }

    public static func removeAll(service: String = defaultService) throws {
        let status = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ] as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStorageError.removeFailed(status)
        }
    }
}

private enum KeychainStorageError: Error {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case removeFailed(OSStatus)
}
