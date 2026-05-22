// swift-tools-version: 6.2
//
// SwiftRigControlTools — developer tooling that lives alongside
// SwiftRigControl but is NOT part of what library consumers pull
// when they add SwiftRigControl as a SwiftPM dependency.
//
// Three categories of executable live here:
//
//   1. HardwareValidation/  — automated smoke tests against real
//      hardware (run with `swift run <Validator>` and the matching
//      <RADIO>_SERIAL_PORT env var). Mirror what's in Tests/HardwareTests/
//      but exercise the full CLI surface end-to-end.
//
//   2. InteractiveValidators/ — tools that need stdin (readLine).
//      They cannot run under XCTest because the test harness captures
//      stdout/stderr and blocks stdin. Use for human-in-the-loop
//      protocol bring-up and debugging.
//
//   3. Debugging/ — vendor- and command-specific debug tools, mostly
//      for Elecraft K-series at the moment.
//
// To build/run, cd into this directory:
//
//   cd Tools/SwiftRigControlTools
//   swift build
//   swift run IC7100Validator        # for example
//
// This package depends on the parent SwiftRigControl package via a
// relative path. Both packages share the same Package.resolved when
// you're working inside this monorepo.

import PackageDescription

let package = Package(
    name: "SwiftRigControlTools",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // MARK: - Hardware Validators

        .executable(name: "IC7100Validator", targets: ["IC7100Validator"]),
        .executable(name: "IC7600Validator", targets: ["IC7600Validator"]),
        .executable(name: "IC9700Validator", targets: ["IC9700Validator"]),
        .executable(name: "K2Validator", targets: ["K2Validator"]),
        .executable(name: "RigctldEmulator", targets: ["RigctldEmulator"]),

        // MARK: - Interactive Validators (require stdin)

        .executable(name: "IC7100ManualValidation", targets: ["IC7100ManualValidation"]),
        .executable(name: "IC7600ManualValidation", targets: ["IC7600ManualValidation"]),
        .executable(name: "IC7600ModeDebug", targets: ["IC7600ModeDebug"]),
        .executable(name: "IC9700ManualValidation", targets: ["IC9700ManualValidation"]),
        .executable(name: "IC9700InteractiveValidator", targets: ["IC9700InteractiveValidator"]),
        .executable(name: "IC9700NRDebug", targets: ["IC9700NRDebug"]),
        .executable(name: "IC7100PTTTest", targets: ["IC7100PTTTest"]),
        .executable(name: "IC7100RITDebug", targets: ["IC7100RITDebug"]),

        // MARK: - Elecraft Debug Tools

        .executable(name: "K2NewCommandsTest", targets: ["K2NewCommandsTest"]),
        .executable(name: "K2PowerDebug", targets: ["K2PowerDebug"]),
        .executable(name: "K2PTTDebug", targets: ["K2PTTDebug"]),
    ],
    dependencies: [
        // Depend on the parent SwiftRigControl package via a relative path.
        .package(path: "../..")
    ],
    targets: [
        // MARK: - Hardware Validation Shared Library

        .target(
            name: "ValidationHelpers",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "HardwareValidation/Shared"
        ),

        // MARK: - Hardware Validators

        .executableTarget(
            name: "IC7100Validator",
            dependencies: [
                .product(name: "RigControl", package: "SwiftRigControl"),
                "ValidationHelpers",
            ],
            path: "HardwareValidation/IC7100Validator"
        ),
        .executableTarget(
            name: "IC7600Validator",
            dependencies: [
                .product(name: "RigControl", package: "SwiftRigControl"),
                "ValidationHelpers",
            ],
            path: "HardwareValidation/IC7600Validator"
        ),
        .executableTarget(
            name: "IC9700Validator",
            dependencies: [
                .product(name: "RigControl", package: "SwiftRigControl"),
                "ValidationHelpers",
            ],
            path: "HardwareValidation/IC9700Validator"
        ),
        .executableTarget(
            name: "K2Validator",
            dependencies: [
                .product(name: "RigControl", package: "SwiftRigControl"),
                "ValidationHelpers",
            ],
            path: "HardwareValidation/K2Validator"
        ),
        .executableTarget(
            name: "RigctldEmulator",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "HardwareValidation/RigctldEmulator"
        ),

        // MARK: - Interactive Validators (Icom)

        .executableTarget(
            name: "IC7100ManualValidation",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC7100ManualValidation"
        ),
        .executableTarget(
            name: "IC7100PTTTest",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC7100PTTTest"
        ),
        .executableTarget(
            name: "IC7100RITDebug",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC7100RITDebug"
        ),
        .executableTarget(
            name: "IC7600ManualValidation",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC7600ManualValidation"
        ),
        .executableTarget(
            name: "IC7600ModeDebug",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC7600ModeDebug"
        ),
        .executableTarget(
            name: "IC9700ManualValidation",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC9700ManualValidation"
        ),
        .executableTarget(
            name: "IC9700InteractiveValidator",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC9700InteractiveValidator"
        ),
        .executableTarget(
            name: "IC9700NRDebug",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "InteractiveValidators/IC9700NRDebug"
        ),

        // MARK: - Elecraft Debug Tools

        .executableTarget(
            name: "K2NewCommandsTest",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "Debugging/K2NewCommandsTest"
        ),
        .executableTarget(
            name: "K2PowerDebug",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "Debugging/K2PowerDebug"
        ),
        .executableTarget(
            name: "K2PTTDebug",
            dependencies: [.product(name: "RigControl", package: "SwiftRigControl")],
            path: "Debugging/K2PTTDebug"
        ),
    ],
    swiftLanguageModes: [.v6]
)
