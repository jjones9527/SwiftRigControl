// swift-tools-version: 6.0
import PackageDescription

// Standalone SwiftRigControl auto-detection validator.
//
// Drop this file and main.swift into a fresh directory on the
// machine that has your radios connected, set the *_SERIAL_PORT
// env vars described in main.swift, and run:
//
//   swift run --package-path .
//
// SPM will fetch SwiftRigControl from GitHub on first run.
//
// To pin to a specific release tag, change the `.branch("main")`
// dependency below to `.exact("1.1.0")` (or whatever tag exists).
let package = Package(
    name: "StandaloneDiscoveryValidator",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/jjones9527/SwiftRigControl.git",
            branch: "main"
        )
    ],
    targets: [
        .executableTarget(
            name: "StandaloneDiscoveryValidator",
            dependencies: [
                .product(name: "RigControl", package: "SwiftRigControl")
            ],
            path: ".",
            exclude: ["Package.swift"],
            sources: ["main.swift"]
        )
    ]
)
