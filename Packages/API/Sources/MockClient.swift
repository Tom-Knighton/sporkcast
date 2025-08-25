//
//  MockClient.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

import Foundation
import Observation

@Observable
public final class MockClient: NetworkClient {
    
    public init() {}
    
    public func get<Entity>(_ endpoint: any Endpoint) async throws -> Entity where Entity : Decodable {
        return endpoint.mockResponseOk() as! Entity
    }
    
    public func getExpect200(_ endpoint: any Endpoint) async throws -> Bool {
        return true
    }
    
    public func put<Entity>(_ endpoint: any Endpoint) async throws -> Entity where Entity : Decodable {
        return endpoint.mockResponseOk() as! Entity
    }
    
    public func post<Entity>(_ endpoint: any Endpoint) async throws -> Entity where Entity : Decodable {
        return endpoint.mockResponseOk() as! Entity
    }
    
    public func delete(_ endpoint: any Endpoint) async throws -> Bool {
        return true
    }
}
