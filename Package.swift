// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if !targetEnvironment(macCatalyst)
let package = Package(
    name: "AirTurnReplacementKeyboard",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "AirTurnReplacementKeyboard",
            targets: ["AirTurnReplacementKeyboard"]
        ),
        .library(
            name: "AirTurnReplacementKeyboardDynamic",
            type: .dynamic,
            targets: ["AirTurnReplacementKeyboard"]
        ),
        .library(
            name: "AirTurnReplacementKeyboardStandard",
            targets: ["AirTurnReplacementKeyboardStandard"]
        ),
        .library(
            name: "AirTurnReplacementKeyboardStandardDynamic",
            type: .dynamic,
            targets: ["AirTurnReplacementKeyboardStandard"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/KeyboardKit/KeyboardKitPro.git", "6.5.0"..<"6.6.0"),
        .package(url: "https://github.com/KeyboardKit/KeyboardKit.git", "6.5.0"..<"6.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "AirTurnReplacementKeyboard",
            dependencies: ["KeyboardKitPro"],
            swiftSettings: [.define("ATRK_PRO")]
        ),
        .target(
            name: "AirTurnReplacementKeyboardStandard",
            dependencies: ["KeyboardKit"],
            swiftSettings: [.define("ATRK_STANDARD")]
        )
    ]
)
#endif
