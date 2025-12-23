import Foundation
import XCTest
@testable import RigControl

/// Common helpers and utilities for hardware tests
enum HardwareTestHelpers {

    /// Lists available serial ports on macOS
    static func listSerialPorts() -> [String] {
        let fileManager = FileManager.default
        let devPath = "/dev"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: devPath) else {
            return []
        }

        // Filter for common serial port patterns
        let serialPorts = contents
            .filter { $0.hasPrefix("cu.") }
            .map { "/dev/\($0)" }
            .sorted()

        return serialPorts
    }

    /// Displays available serial ports for user selection
    static func promptForSerialPort(radioName: String) -> String? {
        let ports = listSerialPorts()

        guard !ports.isEmpty else {
            print("❌ No serial ports found")
            return nil
        }

        print("\n📡 Available Serial Ports for \(radioName):")
        print("==========================================")
        for (index, port) in ports.enumerated() {
            print("  \(index + 1). \(port)")
        }
        print("  0. Skip test")
        print()
        print("Enter port number (or set environment variable):")

        guard let input = readLine(),
              let choice = Int(input),
              choice > 0,
              choice <= ports.count else {
            return nil
        }

        return ports[choice - 1]
    }

    /// Gets serial port from environment or prompts user
    static func getSerialPort(environmentKey: String, radioName: String, interactive: Bool = false) -> String? {
        // First try environment variable
        if let port = ProcessInfo.processInfo.environment[environmentKey] {
            print("✓ Using serial port from environment: \(port)")
            return port
        }

        // If interactive mode, prompt user
        if interactive {
            return promptForSerialPort(radioName: radioName)
        }

        return nil
    }

    /// Formats frequency in MHz
    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }

    /// Confirms PTT test with user (for safety)
    static func confirmPTTTest(radioName: String) -> Bool {
        print("\n⚠️  PTT TEST WARNING")
        print("==========================================")
        print("Radio: \(radioName)")
        print()
        print("This test will key your transmitter for approximately 500ms.")
        print()
        print("IMPORTANT:")
        print("  • Ensure a dummy load or antenna is connected")
        print("  • Set power to minimum (5-10W recommended)")
        print("  • Check your antenna tuner if using one")
        print()
        print("Continue with PTT test? (y/N):")

        guard let input = readLine()?.lowercased(),
              input == "y" || input == "yes" else {
            print("⏭  Skipping PTT test")
            return false
        }

        print("✓ PTT test confirmed, proceeding...")
        return true
    }

    /// Saves current radio state before testing
    struct RadioState {
        let frequency: UInt64
        let mode: Mode
        let power: Int?

        static func save(from rig: RigController) async throws -> RadioState {
            let frequency = try await rig.frequency(vfo: .a, cached: false)
            let mode = try await rig.mode(vfo: .a, cached: false)

            var power: Int?
            let capabilities = await rig.capabilities
            if capabilities.powerControl {
                power = try? await rig.power()
            }

            return RadioState(frequency: frequency, mode: mode, power: power)
        }

        func restore(to rig: RigController) async throws {
            try await rig.setFrequency(frequency, vfo: .a)
            try await rig.setMode(mode, vfo: .a)

            if let power = power {
                try? await rig.setPower(power)
            }
        }
    }

    /// Test result reporter
    struct TestReport {
        var passed: Int = 0
        var failed: Int = 0
        var skipped: Int = 0
        var errors: [String] = []

        mutating func recordPass(_ testName: String) {
            passed += 1
            print("  ✓ \(testName)")
        }

        mutating func recordFailure(_ testName: String, error: String) {
            failed += 1
            errors.append("\(testName): \(error)")
            print("  ✗ \(testName): \(error)")
        }

        mutating func recordSkip(_ testName: String, reason: String) {
            skipped += 1
            print("  ⏭  \(testName): \(reason)")
        }

        func printSummary(radioName: String) {
            print("\n" + String(repeating: "=", count: 50))
            print("Test Summary for \(radioName)")
            print(String(repeating: "=", count: 50))
            print("  Passed:  \(passed)")
            print("  Failed:  \(failed)")
            print("  Skipped: \(skipped)")
            print("  Total:   \(passed + failed + skipped)")

            if !errors.isEmpty {
                print("\nFailures:")
                for error in errors {
                    print("  • \(error)")
                }
            }

            print(String(repeating: "=", count: 50) + "\n")
        }
    }
}

