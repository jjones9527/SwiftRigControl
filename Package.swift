// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftRigControl",
    platforms: [
        .macOS(.v13)  // Minimum macOS 13 for modern async/await and actor features
    ],
    products: [
        // Core library for rig control
        .library(
            name: "RigControl",
            targets: ["RigControl"]
        ),
        // XPC client library for sandboxed apps
        .library(
            name: "RigControlXPC",
            targets: ["RigControlXPC"]
        ),
        // XPC helper executable
        .executable(
            name: "RigControlHelper",
            targets: ["RigControlHelper"]
        ),
    ],
    targets: [
        // Core rig control library
        .target(
            name: "RigControl",
            dependencies: [],
            path: "Sources/RigControl"
        ),

        // XPC client library
        .target(
            name: "RigControlXPC",
            dependencies: ["RigControl"],
            path: "Sources/RigControlXPC"
        ),

        // XPC helper executable
        .executableTarget(
            name: "RigControlHelper",
            dependencies: ["RigControl", "RigControlXPC"],
            path: "Sources/RigControlHelper"
        ),

        // Tests
        .testTarget(
            name: "RigControlTests",
            dependencies: ["RigControl"],
            path: "Tests/RigControlTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
