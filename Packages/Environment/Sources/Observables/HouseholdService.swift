//
//  HouseholdServices.swift
//  API
//
//  Created by Tom Knighton on 11/10/2025.
//

import Foundation
import Observation
import Models
import Combine

public struct HomeResident: Identifiable, Hashable, Equatable, Sendable {
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
    var pendingSupabaseInvite: SupabaseHomeInviteLink? { get set }
    
    @MainActor
    @discardableResult
    func create(named rawName: String) async -> Home?
    
    @MainActor
    @discardableResult
    func leave(disbandIfOwner: Bool) async -> Bool?
    
    @MainActor
    func rename(to rawName: String) async

    @MainActor
    func createSupabaseInviteLink() async throws -> URL?

    @MainActor
    func acceptSupabaseInvite(token: String) async throws -> UUID?
    
    func syncEntities() async
}


@Observable
public final class HouseholdService: HouseholdServiceProtocol, @unchecked Sendable {
    
    public static let shared = HouseholdService()
    
    public var pendingSupabaseInvite: SupabaseHomeInviteLink? = nil
    
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
            try await refreshShareMetadata()

            errorMessage = nil
            return Home(from: newDBHome)
        } catch {
            errorMessage = CustomerFacingErrorMessage.message(
                for: error,
                fallback: "We couldn't create your home right now. Please try again."
            )
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
            try await repository.deleteHome()

            self.residents.removeAll()
            errorMessage = nil
            return true
        } catch {
            print(error.localizedDescription)
            errorMessage = CustomerFacingErrorMessage.message(
                for: error,
                fallback: "We couldn't leave this home right now. Please try again."
            )
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
            errorMessage = CustomerFacingErrorMessage.message(
                for: error,
                fallback: "We couldn't rename this home right now. Please try again."
            )
        }
    }

    public func createSupabaseInviteLink() async throws -> URL? {
        guard let token = try await repository.createSupabaseInviteToken() else { return nil }
        return SupabaseHomeInviteLink(token: token).url
    }

    public func acceptSupabaseInvite(token: String) async throws -> UUID? {
        let homeId = try await repository.acceptSupabaseInviteToken(token)
        try await refreshShareMetadata()
        return homeId
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

        self.residents = try await repository.supabaseResidents(for: home.id)
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
                "Couldn’t update sharing: \(message)"
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
    
    public var pendingSupabaseInvite: SupabaseHomeInviteLink? = nil
    
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
    
    public func createSupabaseInviteLink() async throws -> URL? {
        URL(string: "https://sporkast.tom-knighton.com/join/mock-token")
    }

    public func acceptSupabaseInvite(token: String) async throws -> UUID? {
        home?.id ?? UUID()
    }
    
    public func syncEntities() async {
        return
    }
    
}
