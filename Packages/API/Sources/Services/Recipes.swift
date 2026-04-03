//
//  Recipes.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

import Foundation

public enum Recipes: Endpoint {
    
    case uploadFromUrl(url: String)
    case uploadFromText(text: String, sourceHint: String?)
    
    public func path() -> String {
        switch self {
        case .uploadFromUrl:
            return "Parser/Parse"
        case .uploadFromText:
            return "Parser/ParseText"
        }
    }
    
    public func queryItems() -> [URLQueryItem]? {
        return []
    }
    
    public var body: (any Encodable)? {
        switch self {
        case .uploadFromUrl(let url):
            return ParseRecipeByUrlRequest(url: url)
        case .uploadFromText(let text, let sourceHint):
            return ParseRecipeByTextRequest(text: text, sourceHint: sourceHint)
        }
    }
    
    public func mockResponseOk() -> any Decodable {
        switch self {
        case .uploadFromUrl(_), .uploadFromText:
            return RecipeDTOMockBuilder()
                .build()
        }
    }
}
