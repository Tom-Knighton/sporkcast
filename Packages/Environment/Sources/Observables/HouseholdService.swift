//
//  HouseholdServices.swift
//  API
//
//  Created by Tom Knighton on 11/10/2025.
//

import Foundation
import Observation
import SQLiteData
import Dependencies
import Models
import CloudKit
import Combine
import Persistence

public struct HomeResident: Identifiable, Hashable, Equatable {
    public let name: String
    public let role: String
    public let isUser: Bool
    
    public var id: String { name }
}

public protocol HouseholdServiceProtocol {
    var home: Home? { get }
    var isInHome: Bool { get }
    var canCreate: Bool { get }
    var residents: [HomeResident] { get }
    var pendingInvite: CKShare.Metadata? { get set }
    
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
    
    func syncEntities() async
}


@Observable
public final class HouseholdService: HouseholdServiceProtocol, @unchecked Sendable {
    
    public static let shared = HouseholdService()
    
    public var pendingInvite: CKShare.Metadata? = nil
    
    @ObservationIgnored
    @Dependency(\.defaultSyncEngine) private var syncEngine
    
    @ObservationIgnored
    private let repository: HouseholdRepository
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    public var home: Home? {
        repository.home
    }
    
    private(set) public var residents: [HomeResident] = []
    
    private(set) public var isBusy = false
    private(set) public var errorMessage: String?
    
    public var isInHome: Bool { home != nil }
    public var canCreate: Bool { !isInHome }
    
    
    public init(repository: HouseholdRepository = HouseholdRepository()) {
        self.repository = repository
        if repository.home != nil {
            Task {
                do {
                    try await self.refreshShareMetadata()
                } catch {
                    print(error.localizedDescription)
                }
            }

        }
        
        repository.homePublisher.sink { _ in
            Task {
                do {
                    try await self.refreshShareMetadata()
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        .store(in: &cancellables)        
    }
    
    deinit {
        cancellables.removeAll()
    }

    
    @discardableResult
    public func create(named rawName: String) async -> Home? {
        guard !isBusy else { return home }
        isBusy = true
        defer { isBusy = false }
        
        do {
            let name = sanitize(name: rawName)
            guard !name.isEmpty else { throw CreationError.invalidName }
            guard canCreate else { throw CreationError.alreadyInHousehold }
            
            let newDBHome = try await repository.createHome(named: name)
            
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
        
        if home == nil {
            errorMessage = LeaveError.noHousehold.errorDescription
            return false
        }
        
        isBusy = true
        defer { isBusy = false }
        
        do {
            
            let share = try await repository.shareHome()
            
            if let share {
                let ckDb = share.isCurrentUserOwner ? CKContainer.default().privateCloudDatabase : CKContainer.default().sharedCloudDatabase
                try await ckDb.deleteRecord(withID: share.recordID)
                try await syncEngine.syncChanges()
                try await repository.deleteHome()
                try await syncEngine.deleteLocalData()
            } else {
                try await repository.deleteHome()
            }

            self.residents.removeAll()
            errorMessage = nil
            return true
        } catch {
            print(error.localizedDescription)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
        
    }
    
    public func rename(to rawName: String) async {
        guard home != nil else { return }
        
        do {
            let name = sanitize(name: rawName)
            guard !name.isEmpty else { throw CreationError.invalidName }
            try await repository.updateHomeName(name: name)
            
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    public func share() async throws -> SQLiteData.SharedRecord {
        guard let dbHome = repository._dbHome else { throw HouseholdError.noHome  }
        return try await syncEngine.share(record: dbHome) { share in
            share[CKShare.SystemFieldKey.title] = "Join \(dbHome.name) on Sporkast!"
            share.publicPermission = .readOnly
        }
    }
    
    public func syncEntities() async {
        await repository.syncHomeEntities()
    }
    
    private func sanitize(name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
    
    private func refreshShareMetadata() async throws {
        guard let home else {
            self.residents.removeAll()
            return
        }
        
        let metadataAll = try await repository.homeShareMetadata()
        
        let metadata = metadataAll.first(where: { $0.recordPrimaryKey.uppercased() == home.id.uuidString })
                
        guard let currentUserId = try? await CKContainer.default().userRecordID(), let metadata, let serverRecord = metadata.lastKnownServerRecord, let shareRef = serverRecord.share else {
            return
        }
        
        var residents: [HomeResident] = []
        if let share = try? await CKContainer.default().sharedCloudDatabase.record(for: shareRef.recordID) as? CKShare {
            residents.append(share.owner.toResident(currentId: currentUserId))
            residents.append(contentsOf: share.participants.compactMap { $0.toResident(currentId: currentUserId) }.filter { $0.role != "Owner" })
        } else if let share = try? await CKContainer.default().privateCloudDatabase.record(for: shareRef.recordID) as? CKShare {
            residents.append(share.owner.toResident(currentId: currentUserId))
            residents.append(contentsOf: share.participants.compactMap { $0.toResident(currentId: currentUserId) }.filter { $0.role != "Owner" })
        }
        
        print("Sync residents")
        self.residents = residents
    }
    
    public enum HouseholdError: Error {
        case noHome
    }
}

extension CKShare.Participant {
    func toResident(currentId: CKRecord.ID) -> HomeResident {
        let isOwner = self.role == .owner
        let isCurrent = currentId.recordName == self.userIdentity.userRecordID?.recordName || self.userIdentity.userRecordID?.recordName == "__defaultOwner__"
        
        let status = switch self.acceptanceStatus {
        case .accepted: "Member"
        case .pending: "Pending"
        case .removed: "Left"
        case .unknown: "Unknown"
        default:
            "Unknown"
        }
        let name = isCurrent ? "You" : self.userIdentity.nameComponents?.givenName ?? (isOwner ? "(Owner)" : "(Member)")
        var displayName = "\(name)"
        if let email = self.userIdentity.lookupInfo?.emailAddress {
            displayName += " (\(email))"
        }
        
        displayName += " - \(status)"
        
        return .init(name: displayName, role: isOwner ? "Owner" : "Member", isUser: isCurrent)
    }
}

extension CKShare {
    var isCurrentUserOwner: Bool {
        guard let me = currentUserParticipant else { return false }
        return me.role == .owner
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
                "Couldn’t update CloudKit sharing: \(message)"
            }
        }
    }
}


@Observable
public final class MockHouseholdService: HouseholdServiceProtocol {
    public var home: Home?
    
    public var isInHome: Bool { home != nil }
    
    public var canCreate: Bool { home == nil }
    
    public var residents: [HomeResident] = []
    
    public var pendingInvite: CKShare.Metadata? = nil
    
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
    
    public func syncEntities() async {
        return
    }
    
}
