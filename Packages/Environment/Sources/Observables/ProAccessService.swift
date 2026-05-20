//
//  ProAccessService.swift
//  Environment
//
//  Created by Tom Knighton on 19/05/2026.
//

import Foundation
import Observation
import RevenueCat

public struct ProPlan: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let price: String
    public let duration: ProPlanDuration

    public init(id: String, title: String, price: String, duration: ProPlanDuration) {
        self.id = id
        self.title = title
        self.price = price
        self.duration = duration
    }
}

public enum ProPlanDuration: String, Sendable {
    case monthly
    case yearly
    case lifetime
    case other

    public var sortIndex: Int {
        switch self {
        case .monthly: return 0
        case .yearly: return 1
        case .lifetime: return 2
        case .other: return 3
        }
    }
}

public protocol ProAccessServiceProtocol: AnyObject, Sendable {
    var hasProAccess: Bool { get }
    var subscriptionTier: String { get }
    var availablePlans: [ProPlan] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    @MainActor
    func configure()

    @MainActor
    func refresh() async

    @MainActor
    func purchase(plan: ProPlan) async

    @MainActor
    func restorePurchases() async
}

@Observable
public final class ProAccessService: ProAccessServiceProtocol, @unchecked Sendable {

    #if DEBUG
    private static let apiKey = "test_LLDFxuRGhaxgNbxfraFSrtPXLqP"
    #else
    private static let apiKey = "appl_KQWYKmRLREkFTHMvhmyjqISPxKg"
    #endif
    
    public static let shared = ProAccessService(apiKey: apiKey)

    public private(set) var hasProAccess = false
    public private(set) var subscriptionTier = "free"
    public private(set) var availablePlans: [ProPlan] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let apiKey: String
    @ObservationIgnored private let entitlementIdentifier = "Sporkast Pro"
    @ObservationIgnored private var hasConfigured = false
    @ObservationIgnored private var packagesByPlanID: [String: Package] = [:]

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func configure() {
        guard !hasConfigured else { return }
        Purchases.configure(withAPIKey: apiKey)
        hasConfigured = true
    }

    public func refresh() async {
        configure()
        isLoading = true
        defer { isLoading = false }

        async let customerInfoTask: Void = refreshCustomerInfo()
        async let offeringsTask: Void = refreshOfferings()
        _ = await (customerInfoTask, offeringsTask)
    }

    public func purchase(plan: ProPlan) async {
        configure()
        guard let package = packagesByPlanID[plan.id] else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            errorMessage = nil
        } catch {
            guard !isUserCancelled(error) else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func restorePurchases() async {
        configure()
        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let packages = offerings.current?.availablePackages ?? []
            packagesByPlanID = Dictionary(uniqueKeysWithValues: packages.map { ($0.identifier, $0) })
            availablePlans = packages
                .map { package in
                    ProPlan(
                        id: package.identifier,
                        title: title(for: package),
                        price: package.storeProduct.localizedPriceString,
                        duration: duration(for: package)
                    )
                }
                .sorted { $0.duration.sortIndex < $1.duration.sortIndex }
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[entitlementIdentifier]
        hasProAccess = entitlement?.isActive == true
        subscriptionTier = subscriptionTier(for: entitlement)
    }

    private func subscriptionTier(for entitlement: EntitlementInfo?) -> String {
        guard let entitlement, entitlement.isActive else { return "free" }

        switch entitlement.productIdentifier {
        case "sporkast_pro_monthly", "monthly":
            return "pro_monthly"
        case "sporkast_pro_yearly", "yearly":
            return "pro_yearly"
        case "sporkast_pro_lifetime", "lifetime":
            return "pro_lifetime"
        default:
            return "pro"
        }
    }

    private func duration(for package: Package) -> ProPlanDuration {
        switch package.packageType {
        case .monthly: return .monthly
        case .annual: return .yearly
        case .lifetime: return .lifetime
        default: return .other
        }
    }

    private func title(for package: Package) -> String {
        switch duration(for: package) {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        case .other: return package.storeProduct.localizedTitle
        }
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ErrorCode.errorDomain
            && nsError.code == ErrorCode.purchaseCancelledError.rawValue
    }
}

@Observable
public final class MockProAccessService: ProAccessServiceProtocol, @unchecked Sendable {
    public var hasProAccess: Bool
    public var subscriptionTier: String
    public var availablePlans: [ProPlan]
    public var isLoading = false
    public var errorMessage: String?

    public init(
        hasProAccess: Bool = false,
        subscriptionTier: String = "free",
        availablePlans: [ProPlan] = []
    ) {
        self.hasProAccess = hasProAccess
        self.subscriptionTier = subscriptionTier
        self.availablePlans = availablePlans
    }

    public func configure() {}
    public func refresh() async {}
    public func purchase(plan: ProPlan) async {}
    public func restorePurchases() async {
        hasProAccess = true
        subscriptionTier = "pro"
    }
}
