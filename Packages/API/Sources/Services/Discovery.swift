//
//  Discovery.swift
//  API
//

import Foundation

public enum Discovery: Endpoint {
    case feed(DiscoveryFeedRequest)
    case registerSources(DiscoveryRegisterSourcesRequest)
    case feedback(DiscoveryFeedbackRequest)

    public func path() -> String {
        switch self {
        case .feed:
            return "Discovery/Feed"
        case .registerSources:
            return "Discovery/RegisterSources"
        case .feedback:
            return "Discovery/Feedback"
        }
    }

    public func queryItems() -> [URLQueryItem]? {
        []
    }

    public var body: (any Encodable)? {
        switch self {
        case .feed(let request):
            return request
        case .registerSources(let request):
            return request
        case .feedback(let request):
            return request
        }
    }

    public func mockResponseOk() -> any Decodable {
        switch self {
        case .feed:
            return DiscoveryFeedResponse(sections: [
                DiscoveryFeedSection(
                    id: "for-you",
                    title: "For You",
                    items: [
                        DiscoveryFeedItem(
                            id: "preview",
                            title: "Spiced carrot & lentil soup",
                            sourceUrl: "https://www.bbcgoodfood.com/recipes/spiced-carrot-lentil-soup",
                            sourceDomain: "bbcgoodfood.com",
                            totalMinutes: 25,
                            rating: 4.8,
                            reason: "Good for a cold evening.",
                            tags: ["soup", "quick"]
                        )
                    ]
                )
            ])
        case .registerSources, .feedback:
            return ""
        }
    }
}
