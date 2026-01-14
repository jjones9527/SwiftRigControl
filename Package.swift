// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftRigControl",
    platforms: [
        .macOS(.v13)  // Minimum macOS 13 for modern async/await and actor features
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

        // MARK: - Hardware Validation Tools
        .executable(
            name: "IC7100Validator",
            targets: ["IC7100Validator"]
        ),
        .executable(
            name: "IC7100ManualValidation",
            targets: ["IC7100ManualValidation"]
        ),
        .executable(
            name: "IC7600Validator",
            targets: ["IC7600Validator"]
        ),
        .executable(
            name: "IC9700Validator",
            targets: ["IC9700Validator"]
        ),
        .executable(
            name: "K2Validator",
            targets: ["K2Validator"]
        ),
        .executable(
            name: "RigctldEmulator",
            targets: ["RigctldEmulator"]
        ),
        .executable(
            name: "IC7600ManualValidation",
            targets: ["IC7600ManualValidation"]
        ),
        .executable(
            name: "IC9700ManualValidation",
            targets: ["IC9700ManualValidation"]
        ),
        .executable(
            name: "IC9700InteractiveValidator",
            targets: ["IC9700InteractiveValidator"]
        ),
        .executable(
            name: "IC9700ComprehensiveTest",
            targets: ["IC9700ComprehensiveTest"]
        ),
        .executable(
            name: "IC9700NRDebug",
            targets: ["IC9700NRDebug"]
        ),
        .executable(
            name: "IC7600ComprehensiveTest",
            targets: ["IC7600ComprehensiveTest"]
        ),
        .executable(
            name: "IC7600ModeDebug",
            targets: ["IC7600ModeDebug"]
        ),
        .executable(
            name: "K2Debug",
            targets: ["K2Debug"]
        ),
        .executable(
            name: "K2RITDebug",
            targets: ["K2RITDebug"]
        ),
        .executable(
            name: "K2IFDebug",
            targets: ["K2IFDebug"]
        ),
        .executable(
            name: "K2NewCommandsTest",
            targets: ["K2NewCommandsTest"]
        ),
        .executable(
            name: "K2PowerDebug",
            targets: ["K2PowerDebug"]
        ),
        .executable(
            name: "K2PTTDebug",
            targets: ["K2PTTDebug"]
        ),
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

        // MARK: - Hardware Validation Tools
        .target(
            name: "ValidationHelpers",
            dependencies: ["RigControl"],
            path: "HardwareValidation/Shared"
        ),

        .executableTarget(
            name: "IC7100Validator",
            dependencies: ["RigControl", "ValidationHelpers"],
            path: "HardwareValidation/IC7100Validator"
        ),

        .executableTarget(
            name: "IC7100ManualValidation",
            dependencies: ["RigControl"],
            path: "Sources/IC7100ManualValidation"
        ),

        .executableTarget(
            name: "IC7600Validator",
            dependencies: ["RigControl", "ValidationHelpers"],
            path: "HardwareValidation/IC7600Validator"
        ),

        .executableTarget(
            name: "IC9700Validator",
            dependencies: ["RigControl", "ValidationHelpers"],
            path: "HardwareValidation/IC9700Validator"
        ),

        .executableTarget(
            name: "K2Validator",
            dependencies: ["RigControl", "ValidationHelpers"],
            path: "HardwareValidation/K2Validator"
        ),

        .executableTarget(
            name: "RigctldEmulator",
            dependencies: ["RigControl"],
            path: "HardwareValidation/RigctldEmulator"
        ),

        .executableTarget(
            name: "IC7600ManualValidation",
            dependencies: ["RigControl"],
            path: "Sources/IC7600ManualValidation"
        ),

        .executableTarget(
            name: "IC9700ManualValidation",
            dependencies: ["RigControl"],
            path: "Sources/IC9700ManualValidation"
        ),

        .executableTarget(
            name: "IC9700InteractiveValidator",
            dependencies: ["RigControl"],
            path: "Sources/IC9700InteractiveValidator"
        ),

        .executableTarget(
            name: "IC9700ComprehensiveTest",
            dependencies: ["RigControl"],
            path: "Sources/IC9700ComprehensiveTest"
        ),

        .executableTarget(
            name: "IC9700NRDebug",
            dependencies: ["RigControl"],
            path: "Sources/IC9700NRDebug"
        ),

        .executableTarget(
            name: "IC7600ComprehensiveTest",
            dependencies: ["RigControl"],
            path: "Sources/IC7600ComprehensiveTest"
        ),

        .executableTarget(
            name: "IC7600ModeDebug",
            dependencies: ["RigControl"],
            path: "Sources/IC7600ModeDebug"
        ),

        .executableTarget(
            name: "K2Debug",
            dependencies: ["RigControl"],
            path: "Sources/K2Debug"
        ),

        .executableTarget(
            name: "K2RITDebug",
            dependencies: ["RigControl"],
            path: "Sources/K2RITDebug"
        ),

        .executableTarget(
            name: "K2IFDebug",
            dependencies: ["RigControl"],
            path: "Sources/K2IFDebug"
        ),

        .executableTarget(
            name: "K2NewCommandsTest",
            dependencies: ["RigControl"],
            path: "Sources/K2NewCommandsTest"
        ),

        .executableTarget(
            name: "K2PowerDebug",
            dependencies: ["RigControl"],
            path: "Sources/K2PowerDebug"
        ),

        .executableTarget(
            name: "K2PTTDebug",
            dependencies: ["RigControl"],
            path: "Sources/K2PTTDebug"
        ),

        // MARK: - Tests
        .testTarget(
            name: "RigControlTests",
            dependencies: ["RigControl"],
            path: "Tests/RigControlTests",
            exclude: ["Archived"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
