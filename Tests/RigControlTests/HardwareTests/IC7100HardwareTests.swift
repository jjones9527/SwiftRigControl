import XCTest
@testable import RigControl

/// Comprehensive hardware tests for Icom IC-7100
///
/// The IC-7100 is an HF/VHF/UHF multi-band transceiver with D-STAR capability.
/// Note: IC-7100 does NOT have satellite mode (that's IC-9700).
///
/// ## Running These Tests
///
/// ```bash
/// export IC7100_SERIAL_PORT="/dev/cu.usbserial-2110"
/// swift test --filter IC7100HardwareTests
/// ```
///
final class IC7100HardwareTests: XCTestCase {
    var rig: RigController?
    var savedState: HardwareTestHelpers.RadioState?

    let radioName = "IC-7100"
    let environmentKey = "IC7100_SERIAL_PORT"

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
        print("IC-7100 Hardware Test Suite")
        print(String(repeating: "=", count: 60))
        print("Port: \(port)")
        print(String(repeating: "=", count: 60) + "\n")

        rig = try RigController(
            radio: .icomIC7100(civAddress: nil),
            connection: .serial(path: port, baudRate: nil)
        )

        try await rig!.connect()
        print("✓ Connected to IC-7100\n")

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
        print("   ✓ Disconnected from IC-7100\n")
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

    // MARK: - Multi-Band Tests (HF/VHF/UHF)

    func testHFBands() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🎛️  Test: HF Frequency Control")

        let hfFrequencies: [(freq: UInt64, band: String)] = [
            (1_900_000, "160m"),
            (3_700_000, "80m"),
            (7_100_000, "40m"),
            (14_230_000, "20m"),
            (21_300_000, "15m"),
            (28_500_000, "10m")
        ]

        for (freq, band) in hfFrequencies {
            print("   Testing \(band): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ \(band) verified")
        }

        print("   ✓ All HF bands tested\n")
    }

    func testVHFUHFBands() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: VHF/UHF Frequency Control")

        let vhfuhfFrequencies: [(freq: UInt64, band: String)] = [
            (50_100_000, "6m"),
            (144_200_000, "2m VHF"),
            (430_000_000, "70cm UHF")
        ]

        for (freq, band) in vhfuhfFrequencies {
            print("   Testing \(band): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            XCTAssertEqual(actual, freq)
            print("   ✓ \(band) verified")
        }

        print("   ✓ All VHF/UHF bands tested\n")
    }

    // MARK: - Mode Tests

    func testModeControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: Mode Control")

        try await rig.setFrequency(14_200_000, vfo: .a)

        let modes: [Mode] = [.lsb, .usb, .cw, .rtty, .am, .fm]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")
            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)
            XCTAssertEqual(actual, mode)
            print("   ✓ \(mode.rawValue) verified")
        }

        print("   ✓ All modes tested\n")
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

        print("   Setting power to 10W")
        try await rig.setPower(10)

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

    // MARK: - Power Control

    func testPowerControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Power Control")

        let originalPower = try await rig.power()
        print("   Original power: \(originalPower)W")

        for targetPower in [10, 25, 50, 100] {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)
            let actual = try await rig.power()
            XCTAssertTrue(abs(actual - targetPower) <= 5)
            print("   ✓ Power set to \(actual)W")
        }

        try await rig.setPower(originalPower)
        print("   ✓ Power control verified\n")
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
}
