//
//  Recipes.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

import Foundation

public enum Recipes: Endpoint {
    
    case uploadFromUrl(url: String)
    
    public func path() -> String {
        switch self {
        case .uploadFromUrl:
            return "Parser/Parse"
        }
    }
    
    public func queryItems() -> [URLQueryItem]? {
        return []
    }
    
    public var body: (any Encodable)? {
        switch self {
        case .uploadFromUrl(let url):
            return ParseRecipeByUrlRequest(url: url)
        }
    }
    
    public func mockResponseOk() -> any Decodable {
        switch self {
        case .uploadFromUrl(_):
            return RecipeMockBuilder()
                .build()
        }
    }
}
