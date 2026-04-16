//
//  FlagService.swift
//  Environment
//
//  Created by Tom Knighton on 03/04/2026.
//

@preconcurrency import LaunchDarkly
import Observation
import Foundation

public struct AppFlagContext: Sendable {
    public let appVersion: String
    public let subscriptionTier: String
    
    public init(
        appVersion: String,
        subscriptionTier: String
    ) {
        self.appVersion = appVersion
        self.subscriptionTier = subscriptionTier
    }
}

public enum FeatureFlag: String, Sendable {
    case recipeImportPaprikaEnabled = "recipe-import-paprika-support"
    case recipeChatEnabled = "recipe_chat_enabled"
    case recipeChatSeperateTab = "recipe_chat_seperate_tab"
    case appCollapseTabBar = "app-collapse-tab-bar"
}

public protocol FlagServiceProtocol: Sendable {
    func start()
    func isEnabled(_ flag: FeatureFlag, default defaultValue: Bool) -> Bool
}

@Observable
public final class FlagService: FlagServiceProtocol, @unchecked Sendable {
    public private(set) var hasStarted = false
    
    private let mobileKey: String
    private let context: AppFlagContext
    
    public init(
        mobileKey: String,
        isInternal: Bool = false,
        subscriptionTier: String = "free",
        appVersion: String = FlagService.currentAppVersion
    ) {
        self.mobileKey = mobileKey
        self.context = AppFlagContext(
            appVersion: appVersion,
            subscriptionTier: subscriptionTier
        )
    }
    
    public func start() {
        guard !hasStarted else { return }
        
        var config = LDConfig(
            mobileKey: mobileKey,
            autoEnvAttributes: .enabled
        )
        config.diagnosticOptOut = true
        let installId = InstallationId.get()
        
        var builder = LDContextBuilder(key: installId)
        builder.anonymous(false)
        builder.trySetValue("appVersion", .init(stringLiteral: context.appVersion))
        builder.trySetValue("subscriptionTier", .init(stringLiteral: context.subscriptionTier))
        
        guard case .success(let ldContext) = builder.build() else {
            assertionFailure("Failed to build LaunchDarkly context")
            return
        }
        
        LDClient.start(
            config: config,
            context: ldContext,
            startWaitSeconds: 5
        ) { [weak self] timedOut in
            guard let self else { return }
            self.hasStarted = true
            
#if DEBUG
            if timedOut {
                print("LaunchDarkly timed out during initial start. Using cached/default values until flags refresh.")
            } else {
                print("LaunchDarkly initialized successfully.")
            }
#endif
        }
    }
    
    public func isEnabled(
        _ flag: FeatureFlag,
        default defaultValue: Bool = false
    ) -> Bool {
        guard hasStarted, let client = LDClient.get() else {
            return defaultValue
        }
                
        return client.boolVariation(
            forKey: flag.rawValue,
            defaultValue: defaultValue
        )
    }
    
    public static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

public final class MockFlagService: FlagServiceProtocol {
    private let values: [FeatureFlag: Bool]
    
    public init(values: [FeatureFlag: Bool] = [:]) {
        self.values = values
    }
    
    public func start() {}
    
    public func isEnabled(
        _ flag: FeatureFlag,
        default defaultValue: Bool = false
    ) -> Bool {
        values[flag] ?? defaultValue
    }
}
