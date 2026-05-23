// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// SwiftRigControl: the library consumers depend on.
//
// This package intentionally ships only the runtime artifacts: the
// RigControl library, the XPC helper library, and the XPC helper
// executable. Hardware validators, interactive validators, and
// vendor-specific debug tools live in a separate SwiftPM project at
// `Tools/SwiftRigControlTools/` so they don't bloat downstream
// consumers' build times.
//
// The only declared dependency is Apple's SwiftDocCPlugin, a
// build-time-only SPM plugin that adds the
// `swift package generate-documentation` command. It is NEVER
// linked into the library — downstream consumers pay one git fetch
// at resolve time and nothing else. See the "Build-time-only
// dependencies" exception in CLAUDE.md.
let package = Package(
    name: "SwiftRigControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // MARK: - Core Libraries

        .library(
            name: "RigControl",
            targets: ["RigControl"]
        ),
        .library(
            name: "RigControlXPC",
            targets: ["RigControlXPC"]
        ),

        // MARK: - System Components

        .executable(
            name: "RigControlHelper",
            targets: ["RigControlHelper"]
        ),
    ],
    dependencies: [
        // Build-time only — provides `swift package generate-documentation`.
        // Not linked into the library or any product. See header comment.
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.0"),
    ],
    targets: [
        // MARK: - Core Libraries

        .target(
            name: "RigControl",
            dependencies: [],
            path: "Sources/RigControl"
        ),

        .target(
            name: "RigControlXPC",
            dependencies: ["RigControl"],
            path: "Sources/RigControlXPC"
        ),

        // MARK: - System Components

        .executableTarget(
            name: "RigControlHelper",
            dependencies: ["RigControl", "RigControlXPC"],
            path: "Sources/RigControlHelper"
        ),

        // MARK: - Tests

        .testTarget(
            name: "RigControlTests",
            dependencies: ["RigControl"],
            path: "Tests/RigControlTests",
            exclude: ["Archived"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
