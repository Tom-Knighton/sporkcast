// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
    dependencies: [.package(url: "https://github.com/dimillian/AppRouter.git", from: "1.0.0"), .package(path: "API")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Environment",
            dependencies: [.product(name: "AppRouter", package: "AppRouter"), "API"]
        ),

    ]
)
