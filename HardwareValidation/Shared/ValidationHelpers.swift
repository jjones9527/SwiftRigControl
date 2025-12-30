import Foundation
import RigControl

/// Shared utilities for hardware validation tools
///
/// CRITICAL: This module uses ONLY public APIs from RigControl.
/// It is designed for standalone executables that beta testers will run.
public enum ValidationHelpers {

    // MARK: - Serial Port Discovery

    /// Lists available serial ports on macOS
    public static func listSerialPorts() -> [String] {
        let fileManager = FileManager.default
        let devPath = "/dev"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: devPath) else {
            return []
        }

        // Filter for common serial port patterns (cu.* for dial-out)
        let serialPorts = contents
            .filter { $0.hasPrefix("cu.") }
            .map { "/dev/\($0)" }
            .sorted()

        return serialPorts
    }

    /// Gets serial port from environment variable or exits with helpful message
    public static func getRequiredSerialPort(environmentKey: String, radioName: String) -> String {
        if let port = ProcessInfo.processInfo.environment[environmentKey] {
            return port
        }

        // No environment variable - show helpful message
        print("\n❌ Serial port not configured\n")
        print("Set the \(environmentKey) environment variable:")
        print("  export \(environmentKey)=\"/dev/cu.usbserial-XXXX\"\n")

        let ports = listSerialPorts()
        if !ports.isEmpty {
            print("Available serial ports:")
            for port in ports {
                print("  \(port)")
            }
            print()
        }

        print("Example:")
        print("  export \(environmentKey)=\"\(ports.first ?? "/dev/cu.usbserial-0000")\"")
        print("  swift run \(radioName)Validator\n")

        Foundation.exit(1)
    }

    // MARK: - Formatting

    /// Formats frequency for display
    public static func formatFrequency(_ hz: UInt64) -> String {
        if hz >= 1_000_000_000 {
            let ghz = Double(hz) / 1_000_000_000.0
            return String(format: "%.6f GHz", ghz)
        } else if hz >= 1_000_000 {
            let mhz = Double(hz) / 1_000_000.0
            return String(format: "%.6f MHz", mhz)
        } else {
            let khz = Double(hz) / 1_000.0
            return String(format: "%.3f kHz", khz)
        }
    }

    // MARK: - Radio State Management

    /// Saves and restores radio state for safe testing
    public struct RadioState {
        public let frequency: UInt64
        public let mode: Mode
        public let power: Int?

        /// Saves current radio state
        public static func save(from rig: RigController) async throws -> RadioState {
            let frequency = try await rig.frequency(vfo: .a, cached: false)
            let mode = try await rig.mode(vfo: .a, cached: false)

            var power: Int?
            let capabilities = await rig.capabilities
            if capabilities.powerControl {
                power = try? await rig.power()
            }

            return RadioState(frequency: frequency, mode: mode, power: power)
        }

        /// Restores saved radio state
        public func restore(to rig: RigController) async throws {
            try await rig.setFrequency(frequency, vfo: .a)
            try await rig.setMode(mode, vfo: .a)

            if let power = power {
                try? await rig.setPower(power)
            }
        }

        /// Prints current state
        public func print() {
            Swift.print("   Frequency: \(ValidationHelpers.formatFrequency(frequency))")
            Swift.print("   Mode: \(mode.rawValue)")
            if let power = power {
                Swift.print("   Power: \(power)W")
            }
        }
    }

    // MARK: - PTT Safety

    /// Confirms PTT test with user for safety
    public static func confirmPTTTest(radioName: String, frequency: UInt64, power: Int) -> Bool {
        print("\n⚠️  PTT TEST WARNING")
        print(String(repeating: "=", count: 70))
        print("Radio: \(radioName)")
        print("Frequency: \(formatFrequency(frequency))")
        print("Power: \(power)W")
        print()
        print("This test will key your transmitter.")
        print()
        print("IMPORTANT:")
        print("  • Ensure a dummy load or antenna is connected")
        print("  • Verify the frequency and power settings above")
        print("  • Check your antenna tuner if using one")
        print()
        print("Continue with PTT test? (y/N): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.lowercased().trimmingCharacters(in: .whitespaces),
              input == "y" || input == "yes" else {
            print("⏭  Skipping PTT test\n")
            return false
        }

        print("✓ PTT test confirmed, proceeding...\n")
        return true
    }

    // MARK: - Test Reporting

    /// Tracks and reports test results
    public struct TestReport {
        public var passed: Int = 0
        public var failed: Int = 0
        public var skipped: Int = 0
        public var errors: [(test: String, error: String)] = []

        public init() {}

        public mutating func recordPass() {
            passed += 1
        }

        public mutating func recordFailure(_ testName: String, error: String) {
            failed += 1
            errors.append((test: testName, error: error))
        }

        public mutating func recordSkip(_ testName: String) {
            skipped += 1
        }

        public func printSummary(radioName: String) {
            print("\n" + String(repeating: "=", count: 70))
            print("Test Summary for \(radioName)")
            print(String(repeating: "=", count: 70))
            print("✅ Passed:  \(passed)")
            print("❌ Failed:  \(failed)")
            print("⏭️  Skipped: \(skipped)")
            print("📊 Total:   \(passed + failed + skipped)")
            print(String(repeating: "=", count: 70))

            if failed + passed > 0 {
                let successRate = Double(passed) / Double(passed + failed) * 100
                print("Success Rate: \(String(format: "%.1f", successRate))%")
                print(String(repeating: "=", count: 70))
            }

            if !errors.isEmpty {
                print("\nFailure Details:")
                for (test, error) in errors {
                    print("  ❌ \(test): \(error)")
                }
                print(String(repeating: "=", count: 70))
            }

            print()
        }

        public var exitCode: Int32 {
            return failed == 0 ? 0 : 1
        }
    }

    // MARK: - Output Formatting

    /// Prints a section header
    public static func printHeader(_ title: String) {
        print("\n" + String(repeating: "=", count: 70))
        print(title)
        print(String(repeating: "=", count: 70) + "\n")
    }

    /// Prints a test section
    public static func printTestSection(_ title: String, icon: String = "📡") {
        print("\(icon) \(title)")
    }

    /// Prints a success message
    public static func printSuccess(_ message: String) {
        print("   ✓ \(message)")
    }

    /// Prints an error message
    public static func printError(_ message: String) {
        print("   ❌ \(message)")
    }

    /// Prints a warning message
    public static func printWarning(_ message: String) {
        print("   ⚠️  \(message)")
    }

    /// Prints an info message
    public static func printInfo(_ message: String) {
        print("   \(message)")
    }
}
