//
//  ParseRecipeByTextRequest.swift
//  API
//
//  Created by Tom Knighton on 27/03/2026.
//

public struct ParseRecipeByTextRequest: Encodable {
    public let text: String
    public let sourceHint: String?

    public init(text: String, sourceHint: String?) {
        self.text = text
        self.sourceHint = sourceHint
    }
}
