//
//  APIClient.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

import Foundation

public protocol NetworkClient: Sendable {
    func get<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity
    func getExpect200(_ endpoint: Endpoint) async throws -> Bool
    func put<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity
    func post<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity
    func delete(_ endpoint: Endpoint) async throws -> Bool
}

@Observable
public final class APIClient: NetworkClient, Sendable {
    
    public enum ClientError: Error {
        case unexpectedError
        case invalidUrl
    }
    
    private let host: String
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    
    public init(host: String) {
        self.host = host
        
        self.urlSession = URLSession.shared
        self.decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom({ decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateFormats = ["yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"]
            for format in dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateStr)")
        })
    }
    
    public func get<Entity>(_ endpoint: any Endpoint) async throws -> Entity where Entity : Decodable {
        try await makeEntityRequest(endpoint: endpoint, method: "GET")
    }
    
    public func getExpect200(_ endpoint: Endpoint) async throws -> Bool {
        do {
            let url = try makeURL(endpoint: endpoint)
            let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: "GET")
            let (data, httpResponse) = try await urlSession.data(for: request)
            
            return (httpResponse as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    public func post<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity {
        return try await makeEntityRequest(endpoint: endpoint, method: "POST")
    }
    
    public func put<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity {
        return try await makeEntityRequest(endpoint: endpoint, method: "PUT")
    }
    
    public func delete(_ endpoint: Endpoint) async throws -> Bool {
        do {
            let url = try makeURL(endpoint: endpoint)
            let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: "GET")
            let (data, httpResponse) = try await urlSession.data(for: request)
            
            return (httpResponse as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func makeEntityRequest<Entity: Decodable>(endpoint: Endpoint, method: String) async throws -> Entity {
        let url = try makeURL(endpoint: endpoint)
        let request = makeURLRequest(url: url, endpoint: endpoint, httpMethod: method)
        let (data, httpResponse) = try await urlSession.data(for: request)
        
        if Entity.self is String.Type || Entity.self is Optional<String>.Type {
            return String(data: data, encoding: .utf8) as! Entity
        }
        
        return try decoder.decode(Entity.self, from: data)
    }
    
    private func makeURL(endpoint: Endpoint) throws -> URL
    {
        guard let baseUrl = URL(string: host) else {
            throw ClientError.invalidUrl
        }
        
        let url = baseUrl.appending(path: endpoint.path()).appending(queryItems: endpoint.queryItems() ?? [])
        return url
    }
    
    private func makeURLRequest(url: URL, endpoint: Endpoint, httpMethod: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
                
        if let json = endpoint.body {
            let encoder = JSONEncoder()
            do {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                encoder.dateEncodingStrategy = .formatted(formatter)
                let jsonData = try encoder.encode(json)
                request.httpBody = jsonData
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("Error encoding JSON: \(error.localizedDescription)")
            }
        }
        
        return request
    }
}
