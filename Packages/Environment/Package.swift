// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

private enum BuildFlags {
    private static let truthyValues: Set<String> = [
        "1",
        "true",
        "yes",
        "y"
    ]

    static let enablesIOS27SDK: Bool = {
        guard let value = ProcessInfo.processInfo.environment["ENABLE_IOS_27_SDK"] else {
            return false
        }

        return truthyValues.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }()

    static var betaSDKSwiftSettings: [SwiftSetting] {
        enablesIOS27SDK
            ? [.define("HAS_IOS_27_SDK", .when(platforms: [.iOS]))]
            : []
    }
}

let package = Package(
    name: "Environment",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Environment",
            targets: ["Environment"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/dimillian/AppRouter.git", from: "1.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", .upToNextMajor(from: "11.1.2")),
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", .upToNextMajor(from: "5.78.0")),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.20"),
        .package(path: "../API"),
        .package(path: "../Models"),
        .package(path: "../Persistence")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Environment",
            dependencies: [
                .product(name: "AppRouter", package: "AppRouter"),
                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                "API",
                "Models",
                "Persistence"
            ],
            swiftSettings: BuildFlags.betaSDKSwiftSettings
        ),
        .testTarget(name: "EnvironmentTests", dependencies: ["Environment", "API", "Persistence", "Models"], swiftSettings: BuildFlags.betaSDKSwiftSettings)
    ]
)
