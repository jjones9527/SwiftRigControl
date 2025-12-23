import XCTest
@testable import RigControl

/// Comprehensive hardware tests for Elecraft K2
///
/// The K2 is a high-performance HF QRP transceiver (0-15W) using text-based CAT protocol.
/// Known for excellent receiver performance and CW capabilities.
///
/// ## Running These Tests
///
/// ```bash
/// export K2_SERIAL_PORT="/dev/cu.usbserial-K2"
/// swift test --filter K2HardwareTests
/// ```
///
final class K2HardwareTests: XCTestCase {
    var rig: RigController?
    var savedState: HardwareTestHelpers.RadioState?

    let radioName = "K2"
    let environmentKey = "K2_SERIAL_PORT"

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        guard let port = HardwareTestHelpers.getSerialPort(
            environmentKey: environmentKey,
            radioName: radioName,
            interactive: false
        ) else {
            throw XCTSkip("Set \(environmentKey) environment variable")
        }

        print("\n" + String(repeating: "=", count: 60))
        print("Elecraft K2 Hardware Test Suite")
        print(String(repeating: "=", count: 60))
        print("Port: \(port)")
        print(String(repeating: "=", count: 60) + "\n")

        rig = try RigController(
            radio: .elecraftK2,
            connection: .serial(path: port, baudRate: nil)
        )

        try await rig!.connect()
        print("✓ Connected to Elecraft K2\n")

        savedState = try await HardwareTestHelpers.RadioState.save(from: rig!)
        print("✓ Saved current radio state\n")
    }

    override func tearDown() async throws {
        guard let rig = rig else { return }

        if let savedState = savedState {
            print("\n🔄 Restoring radio state...")
            try await savedState.restore(to: rig)
            print("   ✓ Radio state restored")
        }

        await rig.disconnect()
        print("   ✓ Disconnected from K2\n")
    }

    // MARK: - Basic Tests

    func testConnection() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📡 Test: Basic Connection")

        let freq = try await rig.frequency(vfo: .a, cached: false)
        let mode = try await rig.mode(vfo: .a, cached: false)

        print("   Current frequency: \(HardwareTestHelpers.formatFrequency(freq))")
        print("   Current mode: \(mode.rawValue)")

        XCTAssertGreaterThan(freq, 0)
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
            (10_125_000, "30m"),
            (14_230_000, "20m"),
            (18_100_000, "17m"),
            (21_300_000, "15m"),
            (24_950_000, "12m"),
            (28_500_000, "10m")
        ]

        for (freq, band) in testFrequencies {
            print("   Testing \(band): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ \(band) verified")
        }

        print("   ✓ All HF bands tested\n")
    }

    func testFineFrequencyControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎯 Test: Fine Frequency Control")

        let baseFreq: UInt64 = 14_200_000

        // Test 10 Hz steps (K2 has excellent frequency resolution)
        let offsets: [UInt64] = [0, 10, 50, 100, 500, 1000]

        for offset in offsets {
            let freq = baseFreq + offset
            print("   Setting \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ +\(offset) Hz verified")
        }

        print("   ✓ Fine frequency control verified\n")
    }

    // MARK: - Mode Control Tests

    func testModeControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: Mode Control")

        try await rig.setFrequency(14_200_000, vfo: .a)

        let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .am, .fm]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")
            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)
            XCTAssertEqual(actual, mode)
            print("   ✓ \(mode.rawValue) verified")
        }

        print("   ✓ All modes tested\n")
    }

    // MARK: - Power Control Tests

    func testQRPPowerControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: QRP Power Control (0-15W)")

        let originalPower = try await rig.power()
        print("   Original power: \(originalPower)W")

        // K2 power range: 0-15W (QRP transceiver)
        let testPowers = [1, 3, 5, 10, 15]

        for targetPower in testPowers {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)
            let actual = try await rig.power()

            // Allow ±2W tolerance for QRP levels
            XCTAssertTrue(
                abs(actual - targetPower) <= 2,
                "Power should be approximately \(targetPower)W, got \(actual)W"
            )
            print("   ✓ Power set to \(actual)W")
        }

        try await rig.setPower(originalPower)
        print("   ✓ QRP power control verified\n")
    }

    // MARK: - VFO Tests

    func testVFOControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: VFO A/B Control")

        let freqA: UInt64 = 14_230_000
        let freqB: UInt64 = 14_300_000

        print("   Setting VFO A to \(HardwareTestHelpers.formatFrequency(freqA))")
        try await rig.setFrequency(freqA, vfo: .a)

        print("   Setting VFO B to \(HardwareTestHelpers.formatFrequency(freqB))")
        try await rig.setFrequency(freqB, vfo: .b)

        let actualA = try await rig.frequency(vfo: .a, cached: false)
        let actualB = try await rig.frequency(vfo: .b, cached: false)

        XCTAssertEqual(actualA, freqA)
        XCTAssertEqual(actualB, freqB)

        print("   ✓ VFO A: \(HardwareTestHelpers.formatFrequency(actualA))")
        print("   ✓ VFO B: \(HardwareTestHelpers.formatFrequency(actualB))")
        print("   ✓ VFO control verified\n")
    }

    // MARK: - Split Operation

    func testSplitOperation() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔊 Test: Split Operation")

        try await rig.setFrequency(14_195_000, vfo: .a)
        try await rig.setFrequency(14_225_000, vfo: .b)

        print("   Enabling split")
        try await rig.setSplit(true)
        let enabled = try await rig.isSplitEnabled()
        XCTAssertTrue(enabled)
        print("   ✓ Split enabled")

        print("   Disabling split")
        try await rig.setSplit(false)
        let disabled = try await rig.isSplitEnabled()
        XCTAssertFalse(disabled)
        print("   ✓ Split disabled\n")
    }

    // MARK: - RIT/XIT Tests

    func testRITControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎚️  Test: RIT (Receiver Incremental Tuning)")

        print("   Setting RIT: +500 Hz")
        try await rig.setRIT(RITXITState(enabled: true, offset: 500))

        var ritState = try await rig.getRIT()
        XCTAssertTrue(ritState.enabled)
        XCTAssertEqual(ritState.offset, 500)
        print("   ✓ RIT enabled at +\(ritState.offset) Hz")

        print("   Setting RIT: -300 Hz")
        try await rig.setRIT(RITXITState(enabled: true, offset: -300))

        ritState = try await rig.getRIT()
        XCTAssertEqual(ritState.offset, -300)
        print("   ✓ RIT set to \(ritState.offset) Hz")

        print("   Disabling RIT")
        try await rig.setRIT(RITXITState(enabled: false, offset: 0))

        ritState = try await rig.getRIT()
        XCTAssertFalse(ritState.enabled)
        print("   ✓ RIT disabled\n")
    }

    func testXITControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎚️  Test: XIT (Transmitter Incremental Tuning)")

        print("   Setting XIT: +750 Hz")
        try await rig.setXIT(RITXITState(enabled: true, offset: 750))

        var xitState = try await rig.getXIT()
        XCTAssertTrue(xitState.enabled)
        XCTAssertEqual(xitState.offset, 750)
        print("   ✓ XIT enabled at +\(xitState.offset) Hz")

        print("   Disabling XIT")
        try await rig.setXIT(RITXITState(enabled: false, offset: 0))

        xitState = try await rig.getXIT()
        XCTAssertFalse(xitState.enabled)
        print("   ✓ XIT disabled\n")
    }

    // MARK: - PTT Test

    func testPTTControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        guard HardwareTestHelpers.confirmPTTTest(radioName: radioName) else {
            throw XCTSkip("PTT test skipped by user")
        }

        print("\n📡 Test: PTT Control")

        print("   Setting power to 1W (QRP)")
        try await rig.setPower(1)

        print("   Setting frequency to 14.200 MHz USB")
        try await rig.setFrequency(14_200_000, vfo: .a)
        try await rig.setMode(.usb, vfo: .a)

        print("   ⚠️  Keying in 2 seconds...")
        try await Task.sleep(nanoseconds: 2_000_000_000)

        print("   🔴 PTT ON")
        try await rig.setPTT(true)

        let pttOn = try await rig.isPTTEnabled()
        XCTAssertTrue(pttOn)

        try await Task.sleep(nanoseconds: 500_000_000)

        print("   ⚪ PTT OFF")
        try await rig.setPTT(false)

        let pttOff = try await rig.isPTTEnabled()
        XCTAssertFalse(pttOff)

        print("   ✓ PTT control verified\n")
    }

    // MARK: - CW Tests (K2 Specialty)

    func testCWMode() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: CW Mode (K2 Specialty)")

        try await rig.setFrequency(14_050_000, vfo: .a)

        print("   Setting CW mode")
        try await rig.setMode(.cw, vfo: .a)
        let mode = try await rig.mode(vfo: .a, cached: false)
        XCTAssertEqual(mode, .cw)
        print("   ✓ CW mode verified")

        print("   Setting CW-R mode")
        try await rig.setMode(.cwR, vfo: .a)
        let modeR = try await rig.mode(vfo: .a, cached: false)
        XCTAssertEqual(modeR, .cwR)
        print("   ✓ CW-R mode verified\n")
    }

    // MARK: - Stress Tests

    func testRapidFrequencyChanges() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Rapid Frequency Changes")

        let startFreq: UInt64 = 14_000_000
        let iterations = 30

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
        let avgTime = (duration / Double(iterations)) * 1000

        print("   Completed \(iterations) frequency changes in \(String(format: "%.2f", duration))s")
        print("   Average time per change: \(String(format: "%.1f", avgTime))ms")
        print("   ✓ Rapid frequency changes verified\n")
    }

    // MARK: - Band Edge Tests

    func testBandEdges() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎯 Test: Band Edge Frequencies")

        let bandEdges: [(low: UInt64, high: UInt64, band: String)] = [
            (1_800_000, 2_000_000, "160m"),
            (3_500_000, 4_000_000, "80m"),
            (7_000_000, 7_300_000, "40m"),
            (14_000_000, 14_350_000, "20m"),
            (21_000_000, 21_450_000, "15m"),
            (28_000_000, 29_700_000, "10m")
        ]

        for (low, high, band) in bandEdges {
            print("   Testing \(band) lower edge: \(HardwareTestHelpers.formatFrequency(low))")
            try await rig.setFrequency(low, vfo: .a)
            let actualLow = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actualLow, low)

            print("   Testing \(band) upper edge: \(HardwareTestHelpers.formatFrequency(high))")
            try await rig.setFrequency(high, vfo: .a)
            let actualHigh = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actualHigh, high)

            print("   ✓ \(band) edges verified")
        }

        print("   ✓ All band edges tested\n")
    }

    // MARK: - Signal Strength

    func testSignalStrength() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📊 Test: Signal Strength (S-Meter)")

        for i in 1...5 {
            let strength = try await rig.signalStrength()
            print("   Reading \(i): \(strength.description) (Raw: \(strength.raw))")

            XCTAssertGreaterThanOrEqual(strength.sUnits, 0)
            XCTAssertLessThanOrEqual(strength.sUnits, 9)

            try await Task.sleep(nanoseconds: 200_000_000)
        }

        print("   ✓ S-meter reading verified\n")
    }
}
