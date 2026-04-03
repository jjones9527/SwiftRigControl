import Foundation
import Testing
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
@Suite(.enabled(if: ProcessInfo.processInfo.environment["IC7100_SERIAL_PORT"] != nil,
                "Set IC7100_SERIAL_PORT environment variable"))
struct IC7100HardwareTests {
    var rig: RigController
    var savedState: HardwareTestHelpers.RadioState

    let radioName = "IC-7100"

    init() async throws {
        let port = try #require(ProcessInfo.processInfo.environment["IC7100_SERIAL_PORT"])

        print("\n" + String(repeating: "=", count: 60))
        print("IC-7100 Hardware Test Suite")
        print(String(repeating: "=", count: 60))
        print("Port: \(port)")
        print(String(repeating: "=", count: 60) + "\n")

        rig = try RigController(
            radio: .icomIC7100(civAddress: nil),
            connection: .serial(path: port, baudRate: nil)
        )

        try await rig.connect()
        print("✓ Connected to IC-7100\n")

        savedState = try await HardwareTestHelpers.RadioState.save(from: rig)
        print("✓ Saved current radio state\n")
    }

    // MARK: - Basic Tests

    @Test func connection() async throws {
        print("📡 Test: Basic Connection")

        let freq = try await rig.frequency(vfo: .a, cached: false)
        let mode = try await rig.mode(vfo: .a, cached: false)

        print("   Current frequency: \(HardwareTestHelpers.formatFrequency(freq))")
        print("   Current mode: \(mode.rawValue)")

        #expect(freq > 0)
        print("   ✓ Basic communication verified\n")
    }

    // MARK: - Multi-Band Tests (HF/VHF/UHF)

    @Test func hfBands() async throws {
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
            #expect(actual == freq)
            print("   ✓ \(band) verified")
        }

        try await savedState.restore(to: rig)
        print("   ✓ All HF bands tested\n")
    }

    @Test func vhfUhfBands() async throws {
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
            #expect(actual == freq)
            print("   ✓ \(band) verified")
        }

        try await savedState.restore(to: rig)
        print("   ✓ All VHF/UHF bands tested\n")
    }

    // MARK: - Mode Tests

    @Test func modeControl() async throws {
        print("📻 Test: Mode Control")

        try await rig.setFrequency(14_200_000, vfo: .a)

        let modes: [Mode] = [.lsb, .usb, .cw, .rtty, .am, .fm]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")
            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)
            #expect(actual == mode)
            print("   ✓ \(mode.rawValue) verified")
        }

        try await savedState.restore(to: rig)
        print("   ✓ All modes tested\n")
    }

    // MARK: - Power Control

    @Test func powerControl() async throws {
        print("⚡ Test: Power Control")

        let originalPower = try await rig.power()
        print("   Original power: \(originalPower)W")

        for targetPower in [10, 25, 50, 100] {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)
            let actual = try await rig.power()
            #expect(abs(actual - targetPower) <= 5)
            print("   ✓ Power set to \(actual)W")
        }

        try await rig.setPower(originalPower)
        print("   ✓ Power control verified\n")
    }

    // MARK: - Split Operation

    @Test func splitOperation() async throws {
        print("🔊 Test: Split Operation")

        try await rig.setFrequency(14_195_000, vfo: .a)
        try await rig.setFrequency(14_225_000, vfo: .b)

        print("   Enabling split")
        try await rig.setSplit(true)
        let enabled = try await rig.isSplitEnabled()
        #expect(enabled)
        print("   ✓ Split enabled")

        print("   Disabling split")
        try await rig.setSplit(false)
        let disabled = try await rig.isSplitEnabled()
        #expect(!disabled)
        print("   ✓ Split disabled\n")

        try await savedState.restore(to: rig)
    }
}
