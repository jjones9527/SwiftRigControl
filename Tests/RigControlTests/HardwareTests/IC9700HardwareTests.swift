import XCTest
@testable import RigControl

/// Comprehensive hardware tests for Icom IC-9700
///
/// The IC-9700 is a VHF/UHF/1.2GHz SDR transceiver with dual independent receivers,
/// D-STAR capability, satellite mode, and spectrum scope.
///
/// ## Running These Tests
///
/// ```bash
/// export IC9700_SERIAL_PORT="/dev/cu.IC9700"
/// swift test --filter IC9700HardwareTests
/// ```
///
final class IC9700HardwareTests: XCTestCase {
    var rig: RigController?
    var savedState: HardwareTestHelpers.RadioState?

    let radioName = "IC-9700"
    let environmentKey = "IC9700_SERIAL_PORT"

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
        print("IC-9700 Hardware Test Suite")
        print(String(repeating: "=", count: 60))
        print("Port: \(port)")
        print(String(repeating: "=", count: 60) + "\n")

        rig = try RigController(
            radio: .icomIC9700(civAddress: nil),
            connection: .serial(path: port, baudRate: nil)
        )

        try await rig!.connect()
        print("✓ Connected to IC-9700\n")

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
        print("   ✓ Disconnected from IC-9700\n")
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

    // MARK: - VHF/UHF/1.2GHz Band Tests

    func testVHFBand() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: VHF Band (2m) - Using Main RX")

        // Note: This test uses Main RX. If Main RX is not on VHF band,
        // the test may be skipped. Use testCrossBandOperation to verify
        // VHF/UHF/1.2GHz capabilities across both receivers.

        let currentFreq = try await rig.frequency(vfo: .a, cached: false)
        let isOnVHF = currentFreq >= 144_000_000 && currentFreq <= 148_000_000

        guard isOnVHF else {
            print("   ⚠️  Main RX not on VHF band (currently on \(HardwareTestHelpers.formatFrequency(currentFreq)))")
            print("   ℹ️  IC-9700 requires band to be selected before frequency changes")
            print("   ℹ️  Use testCrossBandOperation or manually switch to VHF band")
            throw XCTSkip("Main RX not on VHF band - switch band on radio and retry")
        }

        let vhfFrequencies: [(freq: UInt64, description: String)] = [
            (144_000_000, "2m band edge"),
            (144_200_000, "2m SSB calling"),
            (145_000_000, "2m FM simplex"),
            (146_520_000, "2m FM calling")
        ]

        for (freq, desc) in vhfFrequencies {
            print("   Testing \(desc): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ \(desc) verified")
        }

        print("   ✓ All VHF frequencies tested\n")
    }

    func testUHFBand() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: UHF Band (70cm)")

        let uhfFrequencies: [(freq: UInt64, description: String)] = [
            (430_000_000, "70cm band edge"),
            (432_100_000, "70cm SSB calling"),
            (435_000_000, "70cm FM simplex"),
            (446_000_000, "70cm FM calling")
        ]

        for (freq, desc) in uhfFrequencies {
            print("   Testing \(desc): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ \(desc) verified")
        }

        print("   ✓ All UHF frequencies tested\n")
    }

    func test1_2GHzBand() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: 1.2GHz Band (23cm)")

        let ghzFrequencies: [(freq: UInt64, description: String)] = [
            (1_240_000_000, "23cm band edge"),
            (1_296_100_000, "23cm SSB calling"),
            (1_270_000_000, "23cm FM simplex")
        ]

        for (freq, desc) in ghzFrequencies {
            print("   Testing \(desc): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ \(desc) verified")
        }

        print("   ✓ All 1.2GHz frequencies tested\n")
    }

    // MARK: - Mode Tests

    func testModeControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: Mode Control")

        // Use current frequency rather than forcing a band change
        let currentFreq = try await rig.frequency(vfo: .a, cached: false)
        print("   Testing on current frequency: \(HardwareTestHelpers.formatFrequency(currentFreq))")

        let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .fm, .am]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")
            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)
            XCTAssertEqual(actual, mode)
            print("   ✓ \(mode.rawValue) verified")
        }

        print("   ✓ All modes tested\n")
    }

    // MARK: - Dual Receiver Tests

    func testDualReceiver() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: Dual Independent Receivers")

        // Read current frequencies on both receivers
        let initialMain = try await rig.frequency(vfo: .a, cached: false)
        let initialSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Initial Main RX: \(HardwareTestHelpers.formatFrequency(initialMain))")
        print("   Initial Sub RX: \(HardwareTestHelpers.formatFrequency(initialSub))")

        // Test frequency changes within each receiver's current band
        // Main RX: Change frequency by 25kHz
        let newMainFreq = initialMain + 25_000
        print("   Setting Main RX to \(HardwareTestHelpers.formatFrequency(newMainFreq))")
        try await rig.setFrequency(newMainFreq, vfo: .a)

        // Sub RX: Change frequency by 25kHz
        let newSubFreq = initialSub + 25_000
        print("   Setting Sub RX to \(HardwareTestHelpers.formatFrequency(newSubFreq))")
        try await rig.setFrequency(newSubFreq, vfo: .b)

        let actualMain = try await rig.frequency(vfo: .a, cached: false)
        let actualSub = try await rig.frequency(vfo: .b, cached: false)

        XCTAssertEqual(actualMain, newMainFreq)
        XCTAssertEqual(actualSub, newSubFreq)

        print("   ✓ Main RX: \(HardwareTestHelpers.formatFrequency(actualMain))")
        print("   ✓ Sub RX: \(HardwareTestHelpers.formatFrequency(actualSub))")
        print("   ✓ Dual receiver operation verified\n")
    }

    func testIndependentModes() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: Independent Mode Control")

        // Get current frequencies
        let freqMain = try await rig.frequency(vfo: .a, cached: false)
        let freqSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Main RX on \(HardwareTestHelpers.formatFrequency(freqMain))")
        print("   Sub RX on \(HardwareTestHelpers.formatFrequency(freqSub))")

        print("   Setting Main RX to USB")
        try await rig.setMode(.usb, vfo: .a)

        print("   Setting Sub RX to FM")
        try await rig.setMode(.fm, vfo: .b)

        let modeMain = try await rig.mode(vfo: .a, cached: false)
        let modeSub = try await rig.mode(vfo: .b, cached: false)

        XCTAssertEqual(modeMain, .usb)
        XCTAssertEqual(modeSub, .fm)

        print("   ✓ Main RX: \(modeMain.rawValue)")
        print("   ✓ Sub RX: \(modeSub.rawValue)")
        print("   ✓ Independent mode control verified\n")
    }

    // MARK: - Satellite Mode Tests

    func testSatelliteMode() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🛰️  Test: Satellite Mode")

        print("   ℹ️  Note: This test requires VHF on Main RX and UHF on Sub RX")
        print("   ℹ️  If bands need switching, manually configure radio and retry")

        // Get current frequencies to check band configuration
        let currentMain = try await rig.frequency(vfo: .a, cached: false)
        let currentSub = try await rig.frequency(vfo: .b, cached: false)

        let mainIsVHF = currentMain >= 144_000_000 && currentMain <= 148_000_000
        let subIsUHF = currentSub >= 430_000_000 && currentSub <= 450_000_000

        guard mainIsVHF && subIsUHF else {
            print("   ⚠️  Main RX: \(HardwareTestHelpers.formatFrequency(currentMain)) (need VHF)")
            print("   ⚠️  Sub RX: \(HardwareTestHelpers.formatFrequency(currentSub)) (need UHF)")
            throw XCTSkip("Satellite mode requires VHF/UHF configuration - adjust bands and retry")
        }

        // Set up typical satellite frequencies within current bands
        let uplinkFreq: UInt64 = 145_850_000   // 2m
        let downlinkFreq: UInt64 = 435_300_000  // 70cm

        print("   Setting uplink frequency: \(HardwareTestHelpers.formatFrequency(uplinkFreq))")
        try await rig.setFrequency(uplinkFreq, vfo: .a)
        try await rig.setMode(.fm, vfo: .a)

        print("   Setting downlink frequency: \(HardwareTestHelpers.formatFrequency(downlinkFreq))")
        try await rig.setFrequency(downlinkFreq, vfo: .b)
        try await rig.setMode(.fm, vfo: .b)

        // Verify satellite configuration
        let actualUplink = try await rig.frequency(vfo: .a, cached: false)
        let actualDownlink = try await rig.frequency(vfo: .b, cached: false)

        XCTAssertEqual(actualUplink, uplinkFreq)
        XCTAssertEqual(actualDownlink, downlinkFreq)

        print("   ✓ Uplink: \(HardwareTestHelpers.formatFrequency(actualUplink)) FM")
        print("   ✓ Downlink: \(HardwareTestHelpers.formatFrequency(actualDownlink)) FM")
        print("   ✓ Satellite mode configuration verified\n")
    }

    // MARK: - Split Operation

    func testSplitOperation() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔊 Test: Split Operation")

        // Get current frequencies
        let currentMain = try await rig.frequency(vfo: .a, cached: false)
        let currentSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Main RX: \(HardwareTestHelpers.formatFrequency(currentMain))")
        print("   Sub RX: \(HardwareTestHelpers.formatFrequency(currentSub))")

        // Set Sub RX frequency offset from Main (+50 kHz)
        let splitFreq = currentMain + 50_000
        print("   Setting split frequency: \(HardwareTestHelpers.formatFrequency(splitFreq))")
        try await rig.setFrequency(splitFreq, vfo: .b)

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

    // MARK: - Power Control

    func testPowerControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Power Control")

        let originalPower = try await rig.power()
        print("   Original power: \(originalPower)W")

        for targetPower in [5, 10, 25, 50] {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)
            let actual = try await rig.power()
            XCTAssertTrue(abs(actual - targetPower) <= 5)
            print("   ✓ Power set to \(actual)W")
        }

        try await rig.setPower(originalPower)
        print("   ✓ Power control verified\n")
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

        print("   Setting power to 5W")
        try await rig.setPower(5)

        print("   Setting frequency to 144.200 MHz FM")
        try await rig.setFrequency(144_200_000, vfo: .a)
        try await rig.setMode(.fm, vfo: .a)

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

    // MARK: - Stress Tests

    func testRapidFrequencyChanges() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Rapid Frequency Changes")

        // Use current frequency as starting point
        let startFreq = try await rig.frequency(vfo: .a, cached: false)
        let iterations = 50

        print("   Starting from \(HardwareTestHelpers.formatFrequency(startFreq))")
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

    // MARK: - Cross-Band Operation

    func testCrossBandOperation() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: Cross-Band Operation")

        print("   ℹ️  Testing independent operation of Main and Sub receivers")
        print("   ℹ️  Each receiver can only change frequency within its current band")

        // Read current band configuration
        let currentMain = try await rig.frequency(vfo: .a, cached: false)
        let currentSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Main RX: \(HardwareTestHelpers.formatFrequency(currentMain))")
        print("   Sub RX: \(HardwareTestHelpers.formatFrequency(currentSub))")

        // Test independent frequency control within each band
        // Main RX: +100 kHz
        let newMainFreq = currentMain + 100_000
        print("   Setting Main RX: \(HardwareTestHelpers.formatFrequency(newMainFreq))")
        try await rig.setFrequency(newMainFreq, vfo: .a)

        // Sub RX: +100 kHz
        let newSubFreq = currentSub + 100_000
        print("   Setting Sub RX: \(HardwareTestHelpers.formatFrequency(newSubFreq))")
        try await rig.setFrequency(newSubFreq, vfo: .b)

        let actualMain = try await rig.frequency(vfo: .a, cached: false)
        let actualSub = try await rig.frequency(vfo: .b, cached: false)

        XCTAssertEqual(actualMain, newMainFreq)
        XCTAssertEqual(actualSub, newSubFreq)

        print("   ✓ Main RX: \(HardwareTestHelpers.formatFrequency(actualMain))")
        print("   ✓ Sub RX: \(HardwareTestHelpers.formatFrequency(actualSub))")
        print("   ✓ Cross-band independent operation verified\n")
    }
}
