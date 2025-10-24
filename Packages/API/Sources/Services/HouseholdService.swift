//
//  HouseholdServices.swift
//  API
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftData
import Foundation
import Observation

@MainActor
@Observable
public final class HouseholdService {
    
    private let context: ModelContext
    
    private(set) public var household: SDHousehold?
    private(set) public var isBusy = false
    private(set) public var errorMessage: String?
    
    public var isInHousehold: Bool { household != nil }
    public var canCreate: Bool { !isInHousehold }
    
    public init(context: ModelContext) {
        self.context = context
        Task { await refresh() }
    }
    
    private func refresh() async {
        do {
            errorMessage = nil
            var desc = FetchDescriptor<SDHousehold>()
            desc.fetchLimit = 1
            desc.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
            household = try context.fetch(desc).first
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @discardableResult
    public func create(named rawName: String) async -> SDHousehold? {
        guard !isBusy else { return household }
        isBusy = true
        defer { isBusy = false }
        
        do {
            let name = sanitize(name: rawName)
            guard !name.isEmpty else { throw CreationError.invalidName }
            guard canCreate else { throw CreationError.alreadyInHousehold }
            
            let h = SDHousehold(name: name)
            context.insert(h)
            try context.save()
            household = h
            errorMessage = nil
            return h
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
        
        guard let h = household else {
            errorMessage = LeaveError.noHousehold.errorDescription
            return false
        }
        
        isBusy = true
        defer { isBusy = false }
        
        do {
            context.delete(h)
            try context.save()
            
            household = nil
            errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
        
    }
    
    public func rename(to rawName: String) async {
        guard let h = household else { return }
        do {
            let name = sanitize(name: rawName)
            guard !name.isEmpty else { throw CreationError.invalidName }
            h.name = name
            h.updatedAt = Date()
            try context.save()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    private func sanitize(name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
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
