//
//  HouseholdServices.swift
//  API
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftData
import Foundation
import Observation
import Persistence
import SQLiteData
import Dependencies
import Models
import CloudKit
import SwiftUI

public protocol HouseholdServiceProtocol {
    var home: Home? { get }
    var isInHome: Bool { get }
    var canCreate: Bool { get }
    
    @MainActor
    @discardableResult
    func create(named rawName: String) async -> Home?
    
    @MainActor
    @discardableResult
    func leave(disbandIfOwner: Bool) async -> Bool?
    
    @MainActor
    func rename(to rawName: String) async
    
    @MainActor
    func share() async throws -> SharedRecord
}

@Observable
public final class HouseholdService: HouseholdServiceProtocol {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database
    
    @ObservationIgnored
    @Dependency(\.defaultSyncEngine) private var syncEngine
    
    @ObservationIgnored
    @FetchOne(DBHome.all) private var dbHome
    
    public var home: Home? {
        get {
            if let dbHome {
                return Home(from: dbHome)
            }
            
            return nil
        }
    }
    
    
    private(set) public var isBusy = false
    private(set) public var errorMessage: String?
    
    public var isInHome: Bool { home != nil }
    public var canCreate: Bool { !isInHome }
    
    
    public init() {}

    
    @discardableResult
    public func create(named rawName: String) async -> Home? {
        guard !isBusy else { return home }
        isBusy = true
        defer { isBusy = false }
        
        do {
            let name = sanitize(name: rawName)
            guard !name.isEmpty else { throw CreationError.invalidName }
            guard canCreate else { throw CreationError.alreadyInHousehold }
            
            let newDBHome = DBHome(id: UUID(), name: name)
            
            try await database.write { db in
                try DBHome.insert { newDBHome }.execute(db)
            }
            
            errorMessage = nil
            return Home(from: newDBHome)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
    
    @discardableResult
    public func leave(disbandIfOwner: Bool = false) async -> Bool? {
        guard !isBusy else {
            errorMessage = LeaveError.busy.errorDescription
            return false
        }
        
        guard let home else {
            errorMessage = LeaveError.noHousehold.errorDescription
            return false
        }
        
        isBusy = true
        defer { isBusy = false }
        
        do {
            let id = home.id
            try await database.write { db in
               try DBHome.find(id).delete().execute(db)
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
        
    }
    
    public func rename(to rawName: String) async {
        guard let home else { return }
        do {
            let name = sanitize(name: rawName)
            guard !name.isEmpty else { throw CreationError.invalidName }
            let id = home.id
            try await database.write { db in
                try DBHome.find(id).update { $0.name = name }.execute(db)
            }

            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    public func share() async throws -> SQLiteData.SharedRecord {
        guard let dbHome else { throw HouseholdError.noHome  }
        return try await syncEngine.share(record: dbHome) { share in
            share[CKShare.SystemFieldKey.title] = "Join \(dbHome.name) on Sporkast!"
            share.publicPermission = .none
        }
    }
    
    private func sanitize(name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
    
    public enum HouseholdError: Error {
        case noHome
    }
}

public extension HouseholdService {
    
    enum CreationError: LocalizedError {
        case alreadyInHousehold
        case invalidName
        public var errorDescription: String? {
            switch self {
            case .alreadyInHousehold: "You’re already in a household."
            case .invalidName: "Please enter a valid name."
            }
        }
    }
    
    enum LeaveError: LocalizedError {
        case noHousehold
        case ownerCannotLeaveWhileOthersExist
        case busy
        case cloudShareOperationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .noHousehold:
                "You’re not currently in a household."
            case .ownerCannotLeaveWhileOthersExist:
                "You’re the owner. You must disband the household or transfer ownership."
            case .busy:
                "Please wait for the current operation to finish."
            case .cloudShareOperationFailed(let message):
                "Couldn’t u pdate CloudKit sharing: \(message)"
            }
        }
    }
}


@Observable
public final class MockHouseholdService: HouseholdServiceProtocol {
    public var home: Home?
    
    public var isInHome: Bool { home != nil }
    
    public var canCreate: Bool { home == nil }
    
    public init(withHome: Bool = false) {
        if withHome {
            self.home = .init(id: UUID(), name: "Mock Home")
        }
    }
    
    public func create(named rawName: String) async -> Models.Home? {
        self.home = .init(id: UUID(), name: rawName)
        return self.home
    }
    
    public func leave(disbandIfOwner: Bool) async -> Bool? {
        self.home = nil
        return true
    }
    
    public func rename(to rawName: String) async {
        self.home?.name = rawName
    }
    
    public func share() async throws -> SQLiteData.SharedRecord {
        throw MockError.notImplemented
    }
    
    public enum MockError: Error {
        case notImplemented
    }
}

