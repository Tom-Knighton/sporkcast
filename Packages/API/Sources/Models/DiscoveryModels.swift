//
//  DiscoveryModels.swift
//  API
//

import Foundation

public struct DiscoveryFeedRequest: Codable, Sendable {
    public var installationId: String
    public var homeId: String?
    public var locale: String?
    public var sourceDomains: [String]
    public var existingRecipeUrls: [String]
    public var weather: DiscoveryWeatherContext?
    public var iCloudUserRecordNameHash: String?
    public var limit: Int

    public init(
        installationId: String,
        homeId: String? = nil,
        locale: String? = nil,
        sourceDomains: [String] = [],
        existingRecipeUrls: [String] = [],
        weather: DiscoveryWeatherContext? = nil,
        iCloudUserRecordNameHash: String? = nil,
        limit: Int = 30
    ) {
        self.installationId = installationId
        self.homeId = homeId
        self.locale = locale
        self.sourceDomains = sourceDomains
        self.existingRecipeUrls = existingRecipeUrls
        self.weather = weather
        self.iCloudUserRecordNameHash = iCloudUserRecordNameHash
        self.limit = limit
    }
}

public struct DiscoveryRegisterSourcesRequest: Codable, Sendable {
    public var installationId: String
    public var homeId: String?
    public var locale: String?
    public var sourceDomains: [String]
    public var existingRecipeUrls: [String]
    public var iCloudUserRecordNameHash: String?

    public init(
        installationId: String,
        homeId: String? = nil,
        locale: String? = nil,
        sourceDomains: [String] = [],
        existingRecipeUrls: [String] = [],
        iCloudUserRecordNameHash: String? = nil
    ) {
        self.installationId = installationId
        self.homeId = homeId
        self.locale = locale
        self.sourceDomains = sourceDomains
        self.existingRecipeUrls = existingRecipeUrls
        self.iCloudUserRecordNameHash = iCloudUserRecordNameHash
    }
}

public struct DiscoveryFeedbackRequest: Codable, Sendable {
    public var installationId: String
    public var homeId: String?
    public var candidateId: String?
    public var iCloudUserRecordNameHash: String?
    public var sourceUrl: String
    public var eventType: DiscoveryFeedbackEventType

    public init(
        installationId: String,
        homeId: String? = nil,
        candidateId: String? = nil,
        iCloudUserRecordNameHash: String? = nil,
        sourceUrl: String,
        eventType: DiscoveryFeedbackEventType
    ) {
        self.installationId = installationId
        self.homeId = homeId
        self.candidateId = candidateId
        self.iCloudUserRecordNameHash = iCloudUserRecordNameHash
        self.sourceUrl = sourceUrl
        self.eventType = eventType
    }
}

public enum DiscoveryFeedbackEventType: String, Codable, Sendable {
    case impression
    case open
    case importStarted
    case importSucceeded
    case hidden
    case notInterested
}

public struct DiscoveryWeatherContext: Codable, Sendable {
    public var condition: String?
    public var temperatureC: Double?
    public var season: String?

    public init(condition: String? = nil, temperatureC: Double? = nil, season: String? = nil) {
        self.condition = condition
        self.temperatureC = temperatureC
        self.season = season
    }
}

public struct DiscoveryFeedResponse: Codable, Sendable {
    public var sections: [DiscoveryFeedSection]

    public init(sections: [DiscoveryFeedSection]) {
        self.sections = sections
    }
}

public struct DiscoveryFeedSection: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var items: [DiscoveryFeedItem]

    public init(id: String, title: String, items: [DiscoveryFeedItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct DiscoveryFeedItem: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var sourceUrl: String
    public var sourceDomain: String
    public var imageUrl: String?
    public var totalMinutes: Double?
    public var rating: Double?
    public var reason: String?
    public var tags: [String]

    public init(
        id: String,
        title: String,
        sourceUrl: String,
        sourceDomain: String,
        imageUrl: String? = nil,
        totalMinutes: Double? = nil,
        rating: Double? = nil,
        reason: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.sourceUrl = sourceUrl
        self.sourceDomain = sourceDomain
        self.imageUrl = imageUrl
        self.totalMinutes = totalMinutes
        self.rating = rating
        self.reason = reason
        self.tags = tags
    }
}
