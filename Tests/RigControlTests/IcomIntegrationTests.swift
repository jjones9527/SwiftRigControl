import XCTest
@testable import RigControl

/// Integration tests for Icom radios with real hardware.
///
/// These tests require an actual Icom radio connected via USB serial.
/// Set the `RIG_SERIAL_PORT` environment variable to your radio's port.
///
/// Example:
/// ```
/// export RIG_SERIAL_PORT="/dev/cu.IC9700"
/// swift test --filter IntegrationTests
/// ```
///
/// **WARNING**: These tests will key your transmitter briefly!
/// Make sure an antenna is connected to avoid damage.
final class IcomIntegrationTests: XCTestCase {
    var rig: RigController?
    var serialPort: String?

    override func setUp() async throws {
        // Get serial port from environment
        guard let port = ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            throw XCTSkip("Set RIG_SERIAL_PORT environment variable to run integration tests")
        }

        serialPort = port

        // Determine radio model from port name
        let radio: RadioDefinition
        if port.contains("IC9700") || port.contains("9700") {
            radio = .icomIC9700
        } else if port.contains("IC7300") || port.contains("7300") {
            radio = .icomIC7300
        } else if port.contains("IC7610") || port.contains("7610") {
            radio = .icomIC7610
        } else if port.contains("IC7600") || port.contains("7600") {
            radio = .icomIC7600
        } else if port.contains("IC7100") || port.contains("7100") {
            radio = .icomIC7100
        } else if port.contains("IC705") || port.contains("705") {
            radio = .icomIC705
        } else {
            // Default to IC-9700 if we can't determine
            radio = .icomIC9700
        }

        rig = RigController(
            radio: radio,
            connection: .serial(path: port)
        )

        try await rig?.connect()
        print("✓ Connected to \(rig?.radioName ?? "radio") at \(port)")
    }

    override func tearDown() async throws {
        await rig?.disconnect()
        rig = nil
        print("✓ Disconnected")
    }

    // MARK: - Frequency Tests

    func testSetAndGetFrequency() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        // Test with 20m SSTV calling frequency
        let targetFreq: UInt64 = 14_230_000

        print("Setting frequency to \(formatFrequency(targetFreq))...")
        try await rig.setFrequency(targetFreq, vfo: .a)

        print("Reading back frequency...")
        let actualFreq = try await rig.frequency(vfo: .a)

        XCTAssertEqual(actualFreq, targetFreq, "Frequency mismatch")
        print("✓ Frequency verified: \(formatFrequency(actualFreq))")
    }

    func testMultipleBands() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        let frequencies: [UInt64] = [
            3_500_000,    // 80m
            7_100_000,    // 40m
            14_230_000,   // 20m
            21_300_000,   // 15m
            28_500_000,   // 10m
        ]

        for freq in frequencies {
            print("Testing \(formatFrequency(freq))...")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a)
            XCTAssertEqual(actual, freq, "Frequency mismatch at \(freq) Hz")
        }

        print("✓ All band changes successful")
    }

    // MARK: - Mode Tests

    func testSetAndGetMode() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        let modes: [Mode] = [.lsb, .usb, .cw, .fm, .am]

        for mode in modes {
            print("Setting mode to \(mode)...")
            try await rig.setMode(mode, vfo: .a)

            print("Reading back mode...")
            let actualMode = try await rig.mode(vfo: .a)

            XCTAssertEqual(actualMode, mode, "Mode mismatch")
            print("✓ Mode verified: \(actualMode)")
        }
    }

    // MARK: - PTT Tests

    func testPTTControl() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        print("WARNING: About to key transmitter for 500ms!")
        print("Waiting 2 seconds...")
        try await Task.sleep(nanoseconds: 2_000_000_000)

        print("Keying transmitter...")
        try await rig.setPTT(true)

        let pttState = try await rig.isPTTEnabled()
        XCTAssertTrue(pttState, "PTT should be enabled")

        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        print("Unkeying transmitter...")
        try await rig.setPTT(false)

        let pttStateOff = try await rig.isPTTEnabled()
        XCTAssertFalse(pttStateOff, "PTT should be disabled")

        print("✓ PTT control successful")
    }

    // MARK: - VFO Tests

    func testVFOSwitching() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        guard rig.capabilities.hasVFOB else {
            throw XCTSkip("Radio doesn't have VFO B")
        }

        print("Setting VFO A to 14.230 MHz...")
        try await rig.setFrequency(14_230_000, vfo: .a)

        print("Setting VFO B to 14.300 MHz...")
        try await rig.setFrequency(14_300_000, vfo: .b)

        print("Verifying frequencies...")
        let freqA = try await rig.frequency(vfo: .a)
        let freqB = try await rig.frequency(vfo: .b)

        XCTAssertEqual(freqA, 14_230_000, "VFO A frequency mismatch")
        XCTAssertEqual(freqB, 14_300_000, "VFO B frequency mismatch")

        print("✓ VFO switching successful")
    }

    // MARK: - Power Control Tests

    func testPowerControl() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        guard rig.capabilities.powerControl else {
            throw XCTSkip("Radio doesn't support power control")
        }

        // Read current power
        let originalPower = try await rig.power()
        print("Original power: \(originalPower)W")

        // Set to 50W
        print("Setting power to 50W...")
        try await rig.setPower(50)

        let power50 = try await rig.power()
        // Allow some tolerance (±5W) due to BCD rounding
        XCTAssertTrue(abs(power50 - 50) <= 5, "Power should be approximately 50W, got \(power50)W")
        print("✓ Power set to \(power50)W")

        // Restore original power
        print("Restoring original power: \(originalPower)W...")
        try await rig.setPower(originalPower)

        print("✓ Power control successful")
    }

    // MARK: - Split Operation Tests

    func testSplitOperation() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        guard rig.capabilities.hasSplit else {
            throw XCTSkip("Radio doesn't support split operation")
        }

        // Set up split operation
        print("Setting up split operation...")
        try await rig.setFrequency(14_195_000, vfo: .a)  // RX
        try await rig.setFrequency(14_225_000, vfo: .b)  // TX

        print("Enabling split...")
        try await rig.setSplit(true)

        let splitEnabled = try await rig.isSplitEnabled()
        XCTAssertTrue(splitEnabled, "Split should be enabled")
        print("✓ Split enabled")

        print("Disabling split...")
        try await rig.setSplit(false)

        let splitDisabled = try await rig.isSplitEnabled()
        XCTAssertFalse(splitDisabled, "Split should be disabled")
        print("✓ Split disabled")
    }

    // MARK: - Stress Tests

    func testRapidCommands() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        print("Testing rapid command execution...")

        for i in 0..<20 {
            let freq: UInt64 = 14_000_000 + UInt64(i * 10_000)
            try await rig.setFrequency(freq, vfo: .a)

            if i % 5 == 0 {
                print("  Completed \(i)/20 commands")
            }
        }

        print("✓ Rapid commands successful")
    }

    func testBoundaryFrequencies() async throws {
        guard let rig = rig else {
            throw XCTSkip("Rig not initialized")
        }

        guard let range = rig.capabilities.frequencyRange else {
            throw XCTSkip("Radio frequency range not defined")
        }

        print("Testing minimum frequency: \(formatFrequency(range.min))...")
        try await rig.setFrequency(range.min, vfo: .a)
        let minFreq = try await rig.frequency(vfo: .a)
        XCTAssertEqual(minFreq, range.min, "Minimum frequency mismatch")

        print("Testing maximum frequency: \(formatFrequency(range.max))...")
        try await rig.setFrequency(range.max, vfo: .a)
        let maxFreq = try await rig.frequency(vfo: .a)
        XCTAssertEqual(maxFreq, range.max, "Maximum frequency mismatch")

        print("✓ Boundary frequencies successful")
    }

    // MARK: - Helper Functions

    private func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
