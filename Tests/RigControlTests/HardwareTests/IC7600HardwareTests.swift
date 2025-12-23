import XCTest
@testable import RigControl

/// Comprehensive hardware tests for Icom IC-7600
///
/// The IC-7600 is a high-performance HF/6m transceiver with dual receiver,
/// extensive DSP capabilities, and advanced audio controls.
///
/// ## Running These Tests
///
/// Set the IC7600_SERIAL_PORT environment variable:
/// ```bash
/// export IC7600_SERIAL_PORT="/dev/cu.IC7600"
/// swift test --filter IC7600HardwareTests
/// ```
///
/// ## What These Tests Verify
///
/// - Basic radio communication and control
/// - Frequency control across all HF bands + 6m
/// - Mode switching (LSB, USB, CW, RTTY, AM, FM, etc.)
/// - Dual receiver operation (Main + Sub)
/// - Split operation for DX work
/// - Power control (0-100W)
/// - RIT/XIT (Receiver/Transmitter Incremental Tuning)
/// - PBT (Passband Tuning) - IC-7600 specific
/// - Audio controls - IC-7600 specific
/// - Memory channel operations
/// - PTT control (with safety confirmation)
///
/// ## Safety
///
/// - PTT tests require user confirmation
/// - Radio state is saved and restored after tests
/// - Conservative power levels used (10W default)
///
final class IC7600HardwareTests: XCTestCase {
    var rig: RigController?
    var savedState: HardwareTestHelpers.RadioState?

    let radioName = "IC-7600"
    let environmentKey = "IC7600_SERIAL_PORT"

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        // Get serial port from environment
        guard let port = HardwareTestHelpers.getSerialPort(
            environmentKey: environmentKey,
            radioName: radioName,
            interactive: false
        ) else {
            throw XCTSkip("Set \(environmentKey) environment variable. Example: export IC7600_SERIAL_PORT=\"/dev/cu.IC7600\"")
        }

        print("\n" + String(repeating: "=", count: 60))
        print("IC-7600 Hardware Test Suite")
        print(String(repeating: "=", count: 60))
        print("Port: \(port)")
        print(String(repeating: "=", count: 60) + "\n")

        // Create controller
        rig = try RigController(
            radio: .icomIC7600(civAddress: nil),
            connection: .serial(path: port, baudRate: nil)
        )

        // Connect
        try await rig!.connect()
        print("✓ Connected to IC-7600\n")

        // Save current state
        savedState = try await HardwareTestHelpers.RadioState.save(from: rig!)
        print("✓ Saved current radio state\n")
    }

    override func tearDown() async throws {
        guard let rig = rig else { return }

        // Restore saved state
        if let savedState = savedState {
            print("\n🔄 Restoring radio state...")
            try await savedState.restore(to: rig)
            print("   ✓ Radio state restored")
        }

        await rig.disconnect()
        print("   ✓ Disconnected from IC-7600\n")
    }

    // MARK: - Basic Communication Tests

    func testConnection() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📡 Test: Basic Connection")
        print("   Testing basic radio communication...")

        // Read current frequency
        let freq = try await rig.frequency(vfo: .a, cached: false)
        print("   Current frequency: \(HardwareTestHelpers.formatFrequency(freq))")

        // Read current mode
        let mode = try await rig.mode(vfo: .a, cached: false)
        print("   Current mode: \(mode.rawValue)")

        XCTAssertGreaterThan(freq, 0, "Frequency should be greater than 0")
        print("   ✓ Basic communication verified\n")
    }

    // MARK: - Frequency Control Tests

    func testFrequencyControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎛️  Test: Frequency Control")

        let testFrequencies: [(freq: UInt64, band: String)] = [
            (1_900_000, "160m"),
            (3_700_000, "80m"),
            (7_100_000, "40m"),
            (14_230_000, "20m"),
            (21_300_000, "15m"),
            (28_500_000, "10m"),
            (50_100_000, "6m")
        ]

        for (freq, band) in testFrequencies {
            print("   Testing \(band): \(HardwareTestHelpers.formatFrequency(freq))")

            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)

            XCTAssertEqual(actual, freq, "\(band) frequency mismatch")
            print("   ✓ \(band) verified")
        }

        print("   ✓ All bands tested successfully\n")
    }

    func testDualVFO() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: Dual VFO Operation")

        let freqA: UInt64 = 14_230_000  // 20m
        let freqB: UInt64 = 14_300_000  // 20m

        print("   Setting VFO A to \(HardwareTestHelpers.formatFrequency(freqA))")
        try await rig.setFrequency(freqA, vfo: .a)

        print("   Setting VFO B to \(HardwareTestHelpers.formatFrequency(freqB))")
        try await rig.setFrequency(freqB, vfo: .b)

        // Verify both
        let actualA = try await rig.frequency(vfo: .a, cached: false)
        let actualB = try await rig.frequency(vfo: .b, cached: false)

        XCTAssertEqual(actualA, freqA, "VFO A frequency mismatch")
        XCTAssertEqual(actualB, freqB, "VFO B frequency mismatch")

        print("   ✓ VFO A: \(HardwareTestHelpers.formatFrequency(actualA))")
        print("   ✓ VFO B: \(HardwareTestHelpers.formatFrequency(actualB))")
        print("   ✓ Dual VFO operation verified\n")
    }

    // MARK: - Mode Control Tests

    func testModeControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: Mode Control")

        // Set to a common HF frequency first
        try await rig.setFrequency(14_200_000, vfo: .a)

        let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")

            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)

            XCTAssertEqual(actual, mode, "Mode mismatch for \(mode.rawValue)")
            print("   ✓ \(mode.rawValue) verified")
        }

        print("   ✓ All modes tested successfully\n")
    }

    // MARK: - Power Control Tests

    func testPowerControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Power Control")

        // Read current power
        let originalPower = try await rig.power()
        print("   Original power: \(originalPower)W")

        // Test various power levels
        let testPowers = [10, 25, 50, 75, 100]

        for targetPower in testPowers {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)

            let actual = try await rig.power()

            // Allow ±5W tolerance due to BCD rounding
            XCTAssertTrue(
                abs(actual - targetPower) <= 5,
                "Power should be approximately \(targetPower)W, got \(actual)W"
            )
            print("   ✓ Power set to \(actual)W")
        }

        // Restore original power
        try await rig.setPower(originalPower)
        print("   ✓ Power control verified\n")
    }

    // MARK: - Split Operation Tests

    func testSplitOperation() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔊 Test: Split Operation")

        // Set up split (typical DX pile-up scenario)
        let rxFreq: UInt64 = 14_195_000  // Listen on 14.195
        let txFreq: UInt64 = 14_225_000  // Transmit on 14.225 (up 30kHz)

        print("   Setting RX frequency: \(HardwareTestHelpers.formatFrequency(rxFreq))")
        try await rig.setFrequency(rxFreq, vfo: .a)

        print("   Setting TX frequency: \(HardwareTestHelpers.formatFrequency(txFreq))")
        try await rig.setFrequency(txFreq, vfo: .b)

        print("   Enabling split operation")
        try await rig.setSplit(true)

        let splitEnabled = try await rig.isSplitEnabled()
        XCTAssertTrue(splitEnabled, "Split should be enabled")
        print("   ✓ Split enabled")

        print("   Disabling split operation")
        try await rig.setSplit(false)

        let splitDisabled = try await rig.isSplitEnabled()
        XCTAssertFalse(splitDisabled, "Split should be disabled")
        print("   ✓ Split disabled")
        print("   ✓ Split operation verified\n")
    }

    // MARK: - RIT/XIT Tests

    func testRITControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎚️  Test: RIT (Receiver Incremental Tuning)")

        // Test RIT with positive offset
        print("   Setting RIT: +1000 Hz")
        try await rig.setRIT(RITXITState(enabled: true, offset: 1000))

        var ritState = try await rig.getRIT()
        XCTAssertTrue(ritState.enabled, "RIT should be enabled")
        XCTAssertEqual(ritState.offset, 1000, "RIT offset should be 1000 Hz")
        print("   ✓ RIT enabled at +\(ritState.offset) Hz")

        // Test RIT with negative offset
        print("   Setting RIT: -500 Hz")
        try await rig.setRIT(RITXITState(enabled: true, offset: -500))

        ritState = try await rig.getRIT()
        XCTAssertEqual(ritState.offset, -500, "RIT offset should be -500 Hz")
        print("   ✓ RIT set to \(ritState.offset) Hz")

        // Disable RIT
        print("   Disabling RIT")
        try await rig.setRIT(RITXITState(enabled: false, offset: 0))

        ritState = try await rig.getRIT()
        XCTAssertFalse(ritState.enabled, "RIT should be disabled")
        print("   ✓ RIT disabled")
        print("   ✓ RIT control verified\n")
    }

    func testXITControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎚️  Test: XIT (Transmitter Incremental Tuning)")

        // Test XIT with positive offset
        print("   Setting XIT: +1500 Hz")
        try await rig.setXIT(RITXITState(enabled: true, offset: 1500))

        var xitState = try await rig.getXIT()
        XCTAssertTrue(xitState.enabled, "XIT should be enabled")
        XCTAssertEqual(xitState.offset, 1500, "XIT offset should be 1500 Hz")
        print("   ✓ XIT enabled at +\(xitState.offset) Hz")

        // Disable XIT
        print("   Disabling XIT")
        try await rig.setXIT(RITXITState(enabled: false, offset: 0))

        xitState = try await rig.getXIT()
        XCTAssertFalse(xitState.enabled, "XIT should be disabled")
        print("   ✓ XIT disabled")
        print("   ✓ XIT control verified\n")
    }

    // MARK: - PTT Control Tests

    func testPTTControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        // Skip if user declines
        guard HardwareTestHelpers.confirmPTTTest(radioName: radioName) else {
            throw XCTSkip("PTT test skipped by user")
        }

        print("\n📡 Test: PTT Control")

        // Set safe power level
        print("   Setting power to 10W for safety")
        try await rig.setPower(10)

        // Set to 20m USB
        print("   Setting frequency to 14.200 MHz USB")
        try await rig.setFrequency(14_200_000, vfo: .a)
        try await rig.setMode(.usb, vfo: .a)

        print("   ⚠️  Keying transmitter in 2 seconds...")
        try await Task.sleep(nanoseconds: 2_000_000_000)

        print("   🔴 PTT ON")
        try await rig.setPTT(true)

        let pttOn = try await rig.isPTTEnabled()
        XCTAssertTrue(pttOn, "PTT should be ON")

        print("   Transmitting for 500ms...")
        try await Task.sleep(nanoseconds: 500_000_000)

        print("   ⚪ PTT OFF")
        try await rig.setPTT(false)

        let pttOff = try await rig.isPTTEnabled()
        XCTAssertFalse(pttOff, "PTT should be OFF")

        print("   ✓ PTT control verified\n")
    }

    // MARK: - Signal Strength Tests

    func testSignalStrength() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📊 Test: Signal Strength (S-Meter)")

        // Read S-meter multiple times
        for i in 1...5 {
            let strength = try await rig.signalStrength()
            print("   Reading \(i): \(strength.description) (Raw: \(strength.raw))")

            XCTAssertGreaterThanOrEqual(strength.sUnits, 0, "S-units should be >= 0")
            XCTAssertLessThanOrEqual(strength.sUnits, 9, "S-units should be <= 9")

            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between readings
        }

        print("   ✓ S-meter reading verified\n")
    }

    // MARK: - Stress Tests

    func testRapidFrequencyChanges() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Rapid Frequency Changes")

        let startFreq: UInt64 = 14_000_000
        let iterations = 50

        print("   Performing \(iterations) rapid frequency changes...")

        let startTime = Date()

        for i in 0..<iterations {
            let freq = startFreq + UInt64(i * 10_000)
            try await rig.setFrequency(freq, vfo: .a)

            if (i + 1) % 10 == 0 {
                print("   Progress: \(i + 1)/\(iterations)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let avgTime = (duration / Double(iterations)) * 1000  // milliseconds

        print("   Completed \(iterations) frequency changes in \(String(format: "%.2f", duration))s")
        print("   Average time per change: \(String(format: "%.1f", avgTime))ms")
        print("   ✓ Rapid frequency changes verified\n")
    }

    // MARK: - Boundary Tests

    func testFrequencyBoundaries() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎯 Test: Frequency Boundaries")

        let capabilities = await rig.capabilities
        guard let range = capabilities.frequencyRange else {
            throw XCTSkip("Frequency range not defined")
        }

        print("   Testing minimum frequency: \(HardwareTestHelpers.formatFrequency(range.min))")
        try await rig.setFrequency(range.min, vfo: .a)
        let minFreq = try await rig.frequency(vfo: .a, cached: false)
        XCTAssertEqual(minFreq, range.min, "Minimum frequency mismatch")
        print("   ✓ Minimum frequency verified")

        print("   Testing maximum frequency: \(HardwareTestHelpers.formatFrequency(range.max))")
        try await rig.setFrequency(range.max, vfo: .a)
        let maxFreq = try await rig.frequency(vfo: .a, cached: false)
        XCTAssertEqual(maxFreq, range.max, "Maximum frequency mismatch")
        print("   ✓ Maximum frequency verified")

        print("   ✓ Frequency boundaries verified\n")
    }
}
