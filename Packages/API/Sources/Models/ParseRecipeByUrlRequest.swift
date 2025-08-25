//
//  ParseRecipeByUrlRequest.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct ParseRecipeByUrlRequest: Encodable {
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}
