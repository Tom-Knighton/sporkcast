//
//  DiscoveryIdentityProvider.swift
//  Environment
//

import CloudKit
import CryptoKit
import Foundation

public struct DiscoveryIdentity: Codable, Hashable, Sendable {
    public let installationId: String
    public let iCloudUserRecordNameHash: String?
    public let homeId: UUID?

    public init(
        installationId: String,
        iCloudUserRecordNameHash: String?,
        homeId: UUID?
    ) {
        self.installationId = installationId
        self.iCloudUserRecordNameHash = iCloudUserRecordNameHash
        self.homeId = homeId
    }
}

public enum DiscoveryIdentityProvider {
    public static func identity(homeId: UUID?) async -> DiscoveryIdentity {
        let recordName = try? await CKContainer.default().userRecordID().recordName
        return DiscoveryIdentity(
            installationId: InstallationId.get(),
            iCloudUserRecordNameHash: recordName.map(hash),
            homeId: homeId
        )
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
