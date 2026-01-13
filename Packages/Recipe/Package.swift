// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Recipe",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Recipe",
            targets: ["Recipe"]
        ),
    ],
    dependencies: [.package(path: "../Design"), .package(path: "../API"), .package(path: "../Environment"), .package(path: "../Persistence"), .package(path: "../Models")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Recipe",
            dependencies: ["Design", "API", "Environment", "Persistence"]
        ),
        .testTarget(
            name: "RecipeTests",
            dependencies: ["Recipe", "Design", "Persistence", "Models"]
        )
    ],
)
