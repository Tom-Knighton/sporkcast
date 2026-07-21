//
//  RecipeIntentSummary.swift
//  Environment
//
//  Created by Tom Knighton on 12/07/2026.
//

import Foundation

public struct RecipeIntentSummary: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let summary: String?
    public let author: String?
    public let keywords: [String]
    public let ingredientNames: [String]
    public let totalMinutes: Double?
    public let prepMinutes: Double?
    public let serves: String?
    public let imageURLString: String?
    public let imageData: Data?

    public init(
        id: UUID,
        title: String,
        summary: String?,
        author: String?,
        keywords: [String],
        ingredientNames: [String],
        totalMinutes: Double?,
        prepMinutes: Double?,
        serves: String?,
        imageURLString: String?,
        imageData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.author = author
        self.keywords = keywords
        self.ingredientNames = ingredientNames
        self.totalMinutes = totalMinutes
        self.prepMinutes = prepMinutes
        self.serves = serves
        self.imageURLString = imageURLString
        self.imageData = imageData
    }
}
