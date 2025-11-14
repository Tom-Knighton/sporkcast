//
//  CloudKitGate.swift
//  Environment
//
//  Created by Tom Knighton on 26/10/2025.
//

import CloudKit
import Observation
import OSLog

public enum CloudGate: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine(Error?)
    case temporarilyUnavailable
    
    public static func == (lhs: CloudGate, rhs: CloudGate) -> Bool {
        switch (lhs, rhs) {
        case (.available, .available),
            (.noAccount, .noAccount),
            (.restricted, .restricted),
            (.temporarilyUnavailable, .temporarilyUnavailable):
            return true
        case (.couldNotDetermine, .couldNotDetermine):
            return true // ignore specific error equality
        default:
            return false
        }
    }
}

@Observable
@MainActor
public final class CloudKitGate {
    public var state: CloudGate = .couldNotDetermine(nil)
    
    @ObservationIgnored
    private var monitorTask: Task<Void, Never>?
    
    @ObservationIgnored
    private let logger = Logger(subsystem: "App.CloudKitGate", category: "CloudKit")
    
    public init() { startMonitoring() }
    deinit { monitorTask?.cancel() }
    
    public func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await self.refresh()
            }
        }
    }
    
    public func refresh() async {
        do {
            switch try await CKContainer.default().accountStatus() {
            case .available:               state = .available
            case .noAccount:               state = .noAccount
            case .restricted:              state = .restricted
            case .temporarilyUnavailable:  state = .temporarilyUnavailable
            case .couldNotDetermine:       fallthrough
            @unknown default:              state = .couldNotDetermine(nil)
            }
        } catch {
            logger.error("accountStatus() failed: \(error.localizedDescription, privacy: .public)")
            state = .couldNotDetermine(error)
        }
    }
    
    public var canUseCloudKit: Bool { state == .available }
    
    public var unavailableReason: String {
        switch state {
        case .available:
            return ""
        case .noAccount:
            return "You’re not signed into iCloud on this device."
        case .restricted:
            return "iCloud is restricted on this device."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again later."
        case .couldNotDetermine(let error):
            if let error { return "Couldn’t determine iCloud status: \(error.localizedDescription)" }
            return "Couldn’t determine iCloud status."
        }
    }
}

