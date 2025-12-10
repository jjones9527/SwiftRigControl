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
        // IC-7100 live test executable
        .executable(
            name: "IC7100LiveTest",
            targets: ["IC7100LiveTest"]
        ),
        // IC-7100 diagnostic test
        .executable(
            name: "IC7100DiagnosticTest",
            targets: ["IC7100DiagnosticTest"]
        ),
        // IC-7100 raw CI-V test
        .executable(
            name: "IC7100RawTest",
            targets: ["IC7100RawTest"]
        ),
        // IC-7100 debug test
        .executable(
            name: "IC7100DebugTest",
            targets: ["IC7100DebugTest"]
        ),
        // IC-7100 interactive test
        .executable(
            name: "IC7100InteractiveTest",
            targets: ["IC7100InteractiveTest"]
        ),
        // IC-7100 mode debug
        .executable(
            name: "IC7100ModeDebug",
            targets: ["IC7100ModeDebug"]
        ),
        // IC-7100 power control test
        .executable(
            name: "IC7100PowerTest",
            targets: ["IC7100PowerTest"]
        ),
        // IC-7100 power debug
        .executable(
            name: "IC7100PowerDebug",
            targets: ["IC7100PowerDebug"]
        ),
        // IC-7100 PTT test
        .executable(
            name: "IC7100PTTTest",
            targets: ["IC7100PTTTest"]
        ),
        // IC-7100 PTT debug
        .executable(
            name: "IC7100PTTDebug",
            targets: ["IC7100PTTDebug"]
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

        // IC-7100 live test executable
        .executableTarget(
            name: "IC7100LiveTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100LiveTest.swift"]
        ),

        // IC-7100 diagnostic test
        .executableTarget(
            name: "IC7100DiagnosticTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100DiagnosticTest.swift"]
        ),

        // IC-7100 raw CI-V test
        .executableTarget(
            name: "IC7100RawTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100RawTest.swift"]
        ),

        // IC-7100 debug test
        .executableTarget(
            name: "IC7100DebugTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100DebugTest.swift"]
        ),

        // IC-7100 interactive test
        .executableTarget(
            name: "IC7100InteractiveTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100InteractiveTest.swift"]
        ),

        // IC-7100 mode debug
        .executableTarget(
            name: "IC7100ModeDebug",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100ModeDebug.swift"]
        ),

        // IC-7100 power control test
        .executableTarget(
            name: "IC7100PowerTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100PowerTest.swift"]
        ),

        // IC-7100 power debug
        .executableTarget(
            name: "IC7100PowerDebug",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100PowerDebug.swift"]
        ),

        // IC-7100 PTT test
        .executableTarget(
            name: "IC7100PTTTest",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100PTTTest.swift"]
        ),

        // IC-7100 PTT debug
        .executableTarget(
            name: "IC7100PTTDebug",
            dependencies: ["RigControl"],
            path: "Tests",
            sources: ["IC7100PTTDebug.swift"]
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
