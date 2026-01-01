// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Design",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Design",
            targets: ["Design"]
        ),
    ],
    dependencies: [.package(url: "https://github.com/kean/Nuke", from: "12.8.0"), .package(path: "API"), .package(path: "Environment"), .package(path: "Models"), .package(path: "Persistence")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Design",
            dependencies: [.product(name: "NukeUI", package: "Nuke"), .product(name: "Nuke", package: "Nuke"), "API", "Environment", "Models", "Persistence"]
        ),
        .testTarget(name: "DesignTests", dependencies: ["Design", "Environment", "Persistence", "Models"])
    ]
)
