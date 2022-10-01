// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AirTurnReplacementKeyboard",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "AirTurnReplacementKeyboard",
            targets: ["AirTurnReplacementKeyboard"]),
        .library(
            name: "AirTurnReplacementKeyboard-dynamic",
            type: .dynamic,
            targets: ["AirTurnReplacementKeyboard"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/KeyboardKit/KeyboardKit", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "AirTurnReplacementKeyboard",
            dependencies: ["KeyboardKit"]),
    ]
)
