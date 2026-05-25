//
//  RecipeDiscoveryRepository.swift
//  API
//

import Foundation

public struct RecipeDiscoveryRepository: Sendable {
    private let client: any NetworkClient

    public init(client: any NetworkClient) {
        self.client = client
    }

    public func feed(_ request: DiscoveryFeedRequest) async throws -> DiscoveryFeedResponse {
        try await client.post(Discovery.feed(request))
    }

    public func registerSources(_ request: DiscoveryRegisterSourcesRequest) async throws {
        let _: String = try await client.post(Discovery.registerSources(request))
    }

    public func recordFeedback(_ request: DiscoveryFeedbackRequest) async throws {
        let _: String = try await client.post(Discovery.feedback(request))
    }
}
