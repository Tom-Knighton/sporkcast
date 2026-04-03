// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RecipeImporting",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RecipeImporting",
            targets: ["RecipeImporting"]
        ),
    ],
    dependencies: [.package(path: "../Models"), .package(path: "../API"), .package(path: "../Environment"), .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0"))],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RecipeImporting",
            dependencies: ["Models", "API", "Environment", "ZIPFoundation"]
        ),
        .testTarget(
            name: "RecipeImportingTests",
            dependencies: ["RecipeImporting", "ZIPFoundation"]
        ),
    ]
)
