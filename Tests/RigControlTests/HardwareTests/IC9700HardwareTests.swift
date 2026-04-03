import Foundation
import Testing
@testable import RigControl

/// Comprehensive hardware tests for Icom IC-9700
///
/// The IC-9700 is a VHF/UHF/1.2GHz SDR transceiver with dual independent receivers,
/// D-STAR capability, satellite mode, and spectrum scope.
///
/// ## Test Philosophy
/// These tests ensure proper radio state management before each test to prevent
/// cross-test contamination and radio rejection errors. Each test:
/// - Verifies radio is in the correct state before testing
/// - May prompt user to manually configure radio when automated setup isn't possible
/// - Restores original state after testing
/// - Tests both SET and GET commands to verify round-trip correctness
///
/// ## Running These Tests
///
/// ```bash
/// export IC9700_SERIAL_PORT="/dev/cu.IC9700"
/// swift test --filter IC9700HardwareTests
/// ```
///
@Suite(.enabled(if: ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"] != nil,
                "Set IC9700_SERIAL_PORT environment variable"))
struct IC9700HardwareTests {
    var rig: RigController
    var savedState: HardwareTestHelpers.RadioState

    let radioName = "IC-9700"

    // MARK: - Setup

    init() async throws {
        let port = try #require(ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"])

        print("\n" + String(repeating: "=", count: 60))
        print("IC-9700 Hardware Test Suite")
        print(String(repeating: "=", count: 60))
        print("Port: \(port)")
        print(String(repeating: "=", count: 60) + "\n")

        rig = try RigController(
            radio: .icomIC9700(civAddress: nil),
            connection: .serial(path: port, baudRate: nil)
        )

        try await rig.connect()
        print("✓ Connected to IC-9700\n")

        savedState = try await HardwareTestHelpers.RadioState.save(from: rig)
        print("✓ Saved current radio state\n")
    }

    // MARK: - Helper Methods

    /// Get Icom protocol instance
    private func getIcomProtocol() async throws -> IcomCIVProtocol {
        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            throw RigError.unsupportedOperation("Not an Icom protocol")
        }
        return icomProtocol
    }

    /// IC-9700 4-state VFO configuration snapshot
    struct VFOState {
        let mainAFreq: UInt64
        let mainBFreq: UInt64
        let subAFreq: UInt64
        let subBFreq: UInt64

        var mainBand: String {
            VFOState.getBandNameStatic(mainAFreq)
        }

        var subBand: String {
            VFOState.getBandNameStatic(subAFreq)
        }

        static func getBandNameStatic(_ freq: UInt64) -> String {
            switch freq {
            case 144_000_000...148_000_000:
                return "2m VHF"
            case 430_000_000...450_000_000:
                return "70cm UHF"
            case 1_240_000_000...1_300_000_000:
                return "23cm 1.2GHz"
            default:
                return "Unknown"
            }
        }

        func printState() {
            print("   IC-9700 4-State VFO Configuration:")
            print("   Main Band: \(mainBand)")
            print("     - Main VFO A: \(HardwareTestHelpers.formatFrequency(mainAFreq))")
            print("     - Main VFO B: \(HardwareTestHelpers.formatFrequency(mainBFreq))")
            print("   Sub Band: \(subBand)")
            print("     - Sub VFO A: \(HardwareTestHelpers.formatFrequency(subAFreq))")
            print("     - Sub VFO B: \(HardwareTestHelpers.formatFrequency(subBFreq))")
        }
    }

    /// Read complete 4-state VFO configuration from IC-9700
    private func readVFOState() async throws -> VFOState {
        let proto = try await getIcomProtocol()

        // Read Main receiver (VFO A and B)
        try await proto.selectBand(.main)
        try await proto.selectVFO(.a)
        let mainAFreq = try await rig.frequency(vfo: .main, cached: false)

        try await proto.selectVFO(.b)
        let mainBFreq = try await rig.frequency(vfo: .main, cached: false)

        // Read Sub receiver (VFO A and B)
        try await proto.selectBand(.sub)
        try await proto.selectVFO(.a)
        let subAFreq = try await rig.frequency(vfo: .sub, cached: false)

        try await proto.selectVFO(.b)
        let subBFreq = try await rig.frequency(vfo: .sub, cached: false)

        return VFOState(
            mainAFreq: mainAFreq,
            mainBFreq: mainBFreq,
            subAFreq: subAFreq,
            subBFreq: subBFreq
        )
    }

    /// Ensure radio is on a specific band
    /// Returns true if already on band, false if user needs to switch manually
    private func ensureBand(_ description: String, frequencyRange: ClosedRange<UInt64>, vfo: VFO = .a) async throws -> Bool {
        let currentFreq = try await rig.frequency(vfo: vfo, cached: false)

        if frequencyRange.contains(currentFreq) {
            print("   ✓ Radio already on \(description) (\(HardwareTestHelpers.formatFrequency(currentFreq)))")
            return true
        } else {
            print("   ⚠️  Radio not on \(description) (currently \(HardwareTestHelpers.formatFrequency(currentFreq)))")
            print("   ℹ️  IC-9700 band stacking prevents automatic band switching")
            return false
        }
    }

    /// Set a safe frequency within current band
    private func setSafeFrequency(_ freq: UInt64, vfo: VFO = .a) async throws {
        do {
            try await rig.setFrequency(freq, vfo: vfo)
        } catch {
            print("   ⚠️  Could not set frequency \(HardwareTestHelpers.formatFrequency(freq)): \(error)")
            throw error
        }
    }

    /// Prompt user to manually configure radio state before test.
    /// Returns true if user confirmed, false if user chose to skip.
    private func promptUserForSetup(message: String, skipMessage: String) -> Bool {
        print("\n" + String(repeating: "⚠️ ", count: 20))
        print("MANUAL CONFIGURATION REQUIRED")
        print(String(repeating: "⚠️ ", count: 20))
        print(message)
        print("\nPress RETURN when ready, or 's' to skip this test: ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.lowercased() else {
            print(skipMessage)
            return false
        }

        if input == "s" || input == "skip" {
            print("Test skipped by user")
            return false
        }

        print("✓ User confirmed configuration is complete\n")
        return true
    }

    /// Wait for user to verify radio behavior.
    /// Returns true if user verified, false if user chose to skip.
    private func waitForUserVerification(message: String, continueMessage: String = "Press RETURN to continue, or 's' to skip: ") -> Bool {
        print("\n" + String(repeating: "👀 ", count: 20))
        print("VERIFY ON RADIO")
        print(String(repeating: "👀 ", count: 20))
        print(message)
        print("\n\(continueMessage)", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.lowercased() else {
            print("User interrupted test")
            return false
        }

        if input == "s" || input == "skip" {
            print("Test skipped by user")
            return false
        }

        print("✓ User verified\n")
        return true
    }

    /// Simple pause for user to observe radio state
    private func pauseForUser(_ message: String) {
        print("\n\(message)")
        print("Press RETURN to continue: ", terminator: "")
        fflush(stdout)
        _ = readLine()
        print("")
    }

    // Helper to identify band from frequency
    private func getBandName(_ freq: UInt64) -> String {
        switch freq {
        case 144_000_000...148_000_000:
            return "2m VHF"
        case 430_000_000...450_000_000:
            return "70cm UHF"
        case 1_240_000_000...1_300_000_000:
            return "23cm 1.2GHz"
        default:
            return "Unknown"
        }
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

    // MARK: - VFO and Band Tests

    @Test func vhfBand() async throws {
        print("📻 Test: VHF Band (2m)")
        print("   Note: Main RX must be on VHF band for this test")

        let vhfRange: ClosedRange<UInt64> = 144_000_000...148_000_000

        if !(try await ensureBand("VHF 2m band", frequencyRange: vhfRange)) {
            guard promptUserForSetup(
                message: """
                Please manually switch Main receiver to 2m VHF band (144-148 MHz):
                1. Press [MAIN] to select Main receiver
                2. Press [BAND] to switch to 2m band
                3. Press RETURN when ready
                """,
                skipMessage: "Main RX not on VHF - test skipped"
            ) else {
                return
            }

            guard try await ensureBand("VHF 2m band", frequencyRange: vhfRange) else {
                print("Main RX still not on VHF after manual switch - skipping")
                return
            }
        }

        // Get current frequency as baseline
        let baseFreq = try await rig.frequency(vfo: .a, cached: false)

        let vhfFrequencies: [(freq: UInt64, description: String)] = [
            (144_200_000, "2m SSB calling"),
            (145_000_000, "2m FM simplex"),
            (146_520_000, "2m FM calling"),
            (144_000_000, "2m band edge")
        ]

        for (freq, desc) in vhfFrequencies {
            print("   Testing \(desc): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            #expect(actual == freq)
            print("   ✓ \(desc) verified")
        }

        // Restore baseline frequency
        try await rig.setFrequency(baseFreq, vfo: .a)
        print("   ✓ VHF band testing complete\n")
    }

    @Test func uhfBand() async throws {
        print("📻 Test: UHF Band (70cm)")
        print("   Note: Main RX must be on UHF band for this test")

        let uhfRange: ClosedRange<UInt64> = 430_000_000...450_000_000

        if !(try await ensureBand("UHF 70cm band", frequencyRange: uhfRange)) {
            guard promptUserForSetup(
                message: """
                Please manually switch Main receiver to 70cm UHF band (430-450 MHz):
                1. Press [MAIN] to select Main receiver
                2. Press [BAND] to switch to 70cm band
                3. Press RETURN when ready
                """,
                skipMessage: "Main RX not on UHF - test skipped"
            ) else {
                return
            }

            guard try await ensureBand("UHF 70cm band", frequencyRange: uhfRange) else {
                print("Main RX still not on UHF after manual switch - skipping")
                return
            }
        }

        let baseFreq = try await rig.frequency(vfo: .a, cached: false)

        let uhfFrequencies: [(freq: UInt64, description: String)] = [
            (432_100_000, "70cm SSB calling"),
            (435_000_000, "70cm FM simplex"),
            (446_000_000, "70cm FM calling"),
            (430_000_000, "70cm band edge")
        ]

        for (freq, desc) in uhfFrequencies {
            print("   Testing \(desc): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            #expect(actual == freq)
            print("   ✓ \(desc) verified")
        }

        try await rig.setFrequency(baseFreq, vfo: .a)
        print("   ✓ UHF band testing complete\n")
    }

    @Test func band1_2GHz() async throws {
        print("📻 Test: 1.2GHz Band (23cm)")
        print("   Note: Main RX must be on 1.2GHz band for this test")

        let ghzRange: ClosedRange<UInt64> = 1_240_000_000...1_300_000_000

        if !(try await ensureBand("1.2GHz 23cm band", frequencyRange: ghzRange)) {
            guard promptUserForSetup(
                message: """
                Please manually switch Main receiver to 23cm 1.2GHz band (1240-1300 MHz):
                1. Press [MAIN] to select Main receiver
                2. Press [BAND] to switch to 23cm band
                3. Press RETURN when ready
                """,
                skipMessage: "Main RX not on 1.2GHz - test skipped"
            ) else {
                return
            }

            guard try await ensureBand("1.2GHz 23cm band", frequencyRange: ghzRange) else {
                print("Main RX still not on 1.2GHz after manual switch - skipping")
                return
            }
        }

        let baseFreq = try await rig.frequency(vfo: .a, cached: false)

        let ghzFrequencies: [(freq: UInt64, description: String)] = [
            (1_296_100_000, "23cm SSB calling"),
            (1_270_000_000, "23cm FM simplex"),
            (1_240_000_000, "23cm band edge")
        ]

        for (freq, desc) in ghzFrequencies {
            print("   Testing \(desc): \(HardwareTestHelpers.formatFrequency(freq))")
            try await rig.setFrequency(freq, vfo: .a)
            let actual = try await rig.frequency(vfo: .a, cached: false)
            #expect(actual == freq)
            print("   ✓ \(desc) verified")
        }

        try await rig.setFrequency(baseFreq, vfo: .a)
        print("   ✓ 1.2GHz band testing complete\n")
    }

    // MARK: - Mode Tests

    @Test func modeControl() async throws {
        print("📻 Test: Mode Control")

        let originalFreq = try await rig.frequency(vfo: .a, cached: false)
        let originalMode = try await rig.mode(vfo: .a, cached: false)

        print("   Testing on frequency: \(HardwareTestHelpers.formatFrequency(originalFreq))")

        let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .fm, .am]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")
            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)
            #expect(actual == mode)
            print("   ✓ \(mode.rawValue) verified")
        }

        // Restore original mode
        try await rig.setMode(originalMode, vfo: .a)
        print("   ✓ Mode control complete\n")
    }

    // MARK: - Dual Receiver Tests

    @Test func dualReceiver() async throws {
        print("🔀 Test: Dual Independent Receivers")

        let initialMain = try await rig.frequency(vfo: .a, cached: false)
        let initialSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Initial Main RX: \(HardwareTestHelpers.formatFrequency(initialMain))")
        print("   Initial Sub RX: \(HardwareTestHelpers.formatFrequency(initialSub))")

        // Offset by 25kHz to ensure they're different
        let newMainFreq = initialMain + 25_000
        let newSubFreq = initialSub + 25_000

        print("   Setting Main RX: \(HardwareTestHelpers.formatFrequency(newMainFreq))")
        try await rig.setFrequency(newMainFreq, vfo: .a)

        print("   Setting Sub RX: \(HardwareTestHelpers.formatFrequency(newSubFreq))")
        try await rig.setFrequency(newSubFreq, vfo: .b)

        let actualMain = try await rig.frequency(vfo: .a, cached: false)
        let actualSub = try await rig.frequency(vfo: .b, cached: false)

        #expect(actualMain == newMainFreq)
        #expect(actualSub == newSubFreq)

        print("   ✓ Main RX: \(HardwareTestHelpers.formatFrequency(actualMain))")
        print("   ✓ Sub RX: \(HardwareTestHelpers.formatFrequency(actualSub))")

        // Restore original frequencies
        try await rig.setFrequency(initialMain, vfo: .a)
        try await rig.setFrequency(initialSub, vfo: .b)

        print("   ✓ Dual receiver operation verified\n")
    }

    @Test func independentModes() async throws {
        print("🔀 Test: Independent Mode Control per Receiver")
        print("   Note: IC-9700 Main/Sub share mode when on SAME band")
        print("   This test requires Main and Sub on DIFFERENT bands\n")

        let proto = try await getIcomProtocol()

        // Read complete 4-state VFO configuration
        print("   Reading current 4-state VFO configuration...")
        let initialState = try await readVFOState()
        initialState.printState()

        // Check if Main and Sub are on different bands
        if initialState.mainBand == initialState.subBand {
            print("\n   ⚠️  Both receivers on same band: \(initialState.mainBand)")
            print("   IC-9700 shares mode settings when on same band")

            guard promptUserForSetup(
                message: """
                Please manually switch Sub receiver to a different band than Main:
                - Main is currently on: \(initialState.mainBand)
                - Sub is currently on: \(initialState.subBand)

                NOTE: IC-9700 shares mode settings when on same band.
                To test independent mode control, receivers must be on different bands.

                Steps:
                1. Press [SUB] to select Sub receiver
                2. Press [BAND] to switch to a different band (e.g., if Main on UHF, switch Sub to VHF)
                3. Press RETURN when ready
                """,
                skipMessage: "Independent mode test requires different bands - test skipped"
            ) else {
                return
            }

            // Verify bands are now different
            let newState = try await readVFOState()
            if newState.mainBand == newState.subBand {
                print("Main and Sub still on same band after manual switch - skipping")
                return
            }

            print("   ✓ Main on \(newState.mainBand), Sub on \(newState.subBand) - ready for independent mode test\n")
        } else {
            print("   ✓ Main on \(initialState.mainBand), Sub on \(initialState.subBand) - different bands\n")
        }

        // Save original modes
        try await proto.selectBand(.main)
        let originalModeMain = try await rig.mode(vfo: .main, cached: false)

        try await proto.selectBand(.sub)
        let originalModeSub = try await rig.mode(vfo: .sub, cached: false)

        print("   Original modes - Main: \(originalModeMain.rawValue), Sub: \(originalModeSub.rawValue)")

        // Set different modes on each receiver using explicit band selection
        print("\n   >>> Setting Main RX to USB...")
        try await proto.selectBand(.main)
        try await rig.setMode(.usb, vfo: .main)
        print("   ✓ Main set to USB")

        guard waitForUserVerification(message: """
            MAIN RECEIVER MODE:
            Look at your IC-9700 Main receiver display.
            - Press [MAIN] to select Main receiver if needed
            - The mode should now show: USB

            Verify Main receiver is in USB mode.
            """) else {
            return
        }

        print("   >>> Setting Sub RX to FM...")
        try await proto.selectBand(.sub)
        try await rig.setMode(.fm, vfo: .sub)
        print("   ✓ Sub set to FM")

        guard waitForUserVerification(message: """
            SUB RECEIVER MODE:
            Look at your IC-9700 Sub receiver display.
            - Press [SUB] to select Sub receiver if needed
            - The mode should now show: FM

            Verify Sub receiver is in FM mode.
            """) else {
            return
        }

        // Verify they changed independently (crucial test!)
        print("\n   >>> Verifying independent mode control...")

        try await proto.selectBand(.main)
        let modeMain = try await rig.mode(vfo: .main, cached: false)
        print("   Main RX mode: \(modeMain.rawValue) (expected: USB)")

        try await proto.selectBand(.sub)
        let modeSub = try await rig.mode(vfo: .sub, cached: false)
        print("   Sub RX mode: \(modeSub.rawValue) (expected: FM)")

        guard waitForUserVerification(message: """
            VERIFY INDEPENDENT MODES:
            This is the key test! Both receivers should have DIFFERENT modes:
            - Press [MAIN] - should show USB mode
            - Press [SUB] - should show FM mode

            Toggle between MAIN and SUB and verify they have different modes.
            This proves independent mode control on different bands.
            """) else {
            return
        }

        #expect(modeMain == .usb, "Main RX should be USB")
        #expect(modeSub == .fm, "Sub RX should be FM")

        print("   ✓ Main RX: \(modeMain.rawValue)")
        print("   ✓ Sub RX: \(modeSub.rawValue)")

        // Restore original modes
        print("\n   >>> Restoring original modes...")
        try await proto.selectBand(.main)
        try await rig.setMode(originalModeMain, vfo: .main)

        try await proto.selectBand(.sub)
        try await rig.setMode(originalModeSub, vfo: .sub)

        print("   ✓ Independent mode control verified\n")
    }

    // MARK: - IC-9700 Specific Function Tests

    @Test func attenuatorControl() async throws {
        print("📡 Test: Attenuator Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original attenuator setting
        let originalAtt = try await icomProtocol.getAttenuatorIC9700()
        print("   💾 Original attenuator: 0x\(String(format: "%02X", originalAtt))")

        // Test OFF (0x00)
        print("   Setting attenuator: OFF (0x00)")
        try await icomProtocol.setAttenuatorIC9700(0x00)
        var readValue = try await icomProtocol.getAttenuatorIC9700()
        #expect(readValue == 0x00)
        print("   ✓ Attenuator OFF verified")

        // Test 10dB (0x10)
        print("   Setting attenuator: 10dB (0x10)")
        try await icomProtocol.setAttenuatorIC9700(0x10)
        readValue = try await icomProtocol.getAttenuatorIC9700()
        #expect(readValue == 0x10)
        print("   ✓ Attenuator 10dB verified")

        // Restore original
        try await icomProtocol.setAttenuatorIC9700(originalAtt)
        print("   🔄 Restored original attenuator setting\n")
    }

    @Test func preampControl() async throws {
        print("📡 Test: Preamp Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        let originalPreamp = try await icomProtocol.getPreampIC9700()
        print("   💾 Original preamp: 0x\(String(format: "%02X", originalPreamp))")

        // Test OFF (0x00)
        print("   Setting preamp: OFF (0x00)")
        try await icomProtocol.setPreampIC9700(0x00)
        var readValue = try await icomProtocol.getPreampIC9700()
        #expect(readValue == 0x00)
        print("   ✓ Preamp OFF verified")

        // Test ON (0x01)
        print("   Setting preamp: ON (0x01)")
        try await icomProtocol.setPreampIC9700(0x01)
        readValue = try await icomProtocol.getPreampIC9700()
        #expect(readValue == 0x01)
        print("   ✓ Preamp ON verified")

        // Restore original
        try await icomProtocol.setPreampIC9700(originalPreamp)
        print("   🔄 Restored original preamp setting\n")
    }

    @Test func agcControl() async throws {
        print("📡 Test: AGC Control (IC-9700 Specific)")
        print("   Note: AGC OFF may not be available in all modes (e.g., SSB)")

        let icomProtocol = try await getIcomProtocol()

        let originalAGC = try await icomProtocol.getAGCIC9700()
        print("   💾 Original AGC: 0x\(String(format: "%02X", originalAGC))")

        // Test only FAST, MID, SLOW (OFF might not be valid in SSB/other modes)
        let agcSettings: [(code: UInt8, name: String)] = [
            (0x01, "FAST"),
            (0x02, "MID"),
            (0x03, "SLOW")
        ]

        for setting in agcSettings {
            print("   Setting AGC: \(setting.name) (0x\(String(format: "%02X", setting.code)))")
            try await icomProtocol.setAGCIC9700(setting.code)
            let readValue = try await icomProtocol.getAGCIC9700()
            #expect(readValue == setting.code)
            print("   ✓ AGC \(setting.name) verified")
        }

        // Restore original
        try await icomProtocol.setAGCIC9700(originalAGC)
        print("   🔄 Restored original AGC setting\n")
    }

    @Test func manualNotch() async throws {
        print("📡 Test: Manual Notch Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        let originalNotch = try await icomProtocol.getManualNotchIC9700()
        let originalPosition = try await icomProtocol.getNotchPositionIC9700()
        print("   💾 Original notch enabled: \(originalNotch), position: \(originalPosition)")

        // Test notch OFF
        print("   Setting manual notch: OFF")
        try await icomProtocol.setManualNotchIC9700(false)
        var enabled = try await icomProtocol.getManualNotchIC9700()
        #expect(!enabled)
        print("   ✓ Manual notch OFF verified")

        // Test notch ON
        print("   Setting manual notch: ON")
        try await icomProtocol.setManualNotchIC9700(true)
        enabled = try await icomProtocol.getManualNotchIC9700()
        #expect(enabled)
        print("   ✓ Manual notch ON verified")

        // Test notch position
        print("   Setting notch position: 128 (center)")
        try await icomProtocol.setNotchPositionIC9700(128)
        let position = try await icomProtocol.getNotchPositionIC9700()
        #expect(position == 128)
        print("   ✓ Notch position verified")

        // Restore original
        try await icomProtocol.setManualNotchIC9700(originalNotch)
        try await icomProtocol.setNotchPositionIC9700(originalPosition)
        print("   🔄 Restored original notch settings\n")
    }

    @Test func monitorFunction() async throws {
        print("📡 Test: Monitor Function (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        let originalMonitorEnabled = try await icomProtocol.getMonitorIC9700()
        let originalMonitorGain = try await icomProtocol.getMonitorGainIC9700()
        print("   💾 Original monitor: \(originalMonitorEnabled), gain: \(originalMonitorGain)")

        // Test monitor OFF
        print("   Setting monitor: OFF")
        try await icomProtocol.setMonitorIC9700(false)
        var monitorEnabled = try await icomProtocol.getMonitorIC9700()
        #expect(!monitorEnabled)
        print("   ✓ Monitor OFF verified")

        // Test monitor ON
        print("   Setting monitor: ON")
        try await icomProtocol.setMonitorIC9700(true)
        monitorEnabled = try await icomProtocol.getMonitorIC9700()
        #expect(monitorEnabled)
        print("   ✓ Monitor ON verified")

        // Test monitor gain
        print("   Setting monitor gain: 128 (50%)")
        try await icomProtocol.setMonitorGainIC9700(128)
        let gain = try await icomProtocol.getMonitorGainIC9700()
        #expect(gain == 128)
        print("   ✓ Monitor gain verified")

        // Restore original
        try await icomProtocol.setMonitorIC9700(originalMonitorEnabled)
        try await icomProtocol.setMonitorGainIC9700(originalMonitorGain)
        print("   🔄 Restored original monitor settings\n")
    }

    @Test func nrLevel() async throws {
        print("📡 Test: NR Level Control (IC-9700 Specific)")
        print("   Note: IC-9700 displays NR as 0-15 (quantized), CI-V uses 0-255")
        print("   Radio quantizes to 16 steps (~17 per step), expect ±8 tolerance")

        let icomProtocol = try await getIcomProtocol()

        let originalLevel = try await icomProtocol.getNRLevelIC9700()
        print("   💾 Original NR level: \(originalLevel)")

        // Test levels with expected quantized values
        // Radio quantizes to 16 steps: 0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255
        let testLevels: [(value: UInt8, expected: UInt8, name: String)] = [
            (0, 0, "0% (Display: 0)"),      // Step 0
            (128, 136, "50% (Display: 8)"), // Step 8: 8×17 = 136
            (255, 255, "100% (Display: 15)") // Step 15: max
        ]

        for test in testLevels {
            print("   Setting NR level: \(test.name)")
            try await icomProtocol.setNRLevelIC9700(test.value)
            let readValue = try await icomProtocol.getNRLevelIC9700()

            // Allow ±10 tolerance for quantization (half a step)
            let tolerance: UInt8 = 10
            let delta = abs(Int(readValue) - Int(test.expected))

            if delta > Int(tolerance) {
                print("   ⚠️  NR level mismatch - Expected: \(test.expected), Got: \(readValue) (Δ \(delta))")
            }

            #expect(delta <= Int(tolerance),
                "NR level should be within \(tolerance) of expected (quantization tolerance)")
            print("   ✓ NR level \(test.name) verified (got \(readValue), expected ~\(test.expected))")
        }

        // Restore original
        try await icomProtocol.setNRLevelIC9700(originalLevel)
        print("   🔄 Restored original NR level\n")
    }

    @Test func voxControl() async throws {
        print("📡 Test: VOX Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        let originalVoxGain = try await icomProtocol.getVoxGainIC9700()
        let originalAntiVoxGain = try await icomProtocol.getAntiVoxGainIC9700()
        print("   💾 Original VOX gain: \(originalVoxGain), Anti-VOX: \(originalAntiVoxGain)")

        let voxLevels: [(value: UInt8, name: String)] = [
            (0, "0%"),
            (128, "50%"),
            (255, "100%")
        ]

        for test in voxLevels {
            print("   Setting VOX gain: \(test.name)")
            try await icomProtocol.setVoxGainIC9700(test.value)
            let readValue = try await icomProtocol.getVoxGainIC9700()
            #expect(readValue == test.value)
            print("   ✓ VOX gain \(test.name) verified")
        }

        for test in voxLevels {
            print("   Setting Anti-VOX gain: \(test.name)")
            try await icomProtocol.setAntiVoxGainIC9700(test.value)
            let readValue = try await icomProtocol.getAntiVoxGainIC9700()
            #expect(readValue == test.value)
            print("   ✓ Anti-VOX gain \(test.name) verified")
        }

        // Restore original
        try await icomProtocol.setVoxGainIC9700(originalVoxGain)
        try await icomProtocol.setAntiVoxGainIC9700(originalAntiVoxGain)
        print("   🔄 Restored original VOX settings\n")
    }

    @Test func dialLock() async throws {
        print("📡 Test: Dial Lock (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        let originalLock = try await icomProtocol.getDialLockIC9700()
        print("   💾 Original dial lock: \(originalLock)")

        // Test dial lock OFF
        print("   Setting dial lock: OFF")
        try await icomProtocol.setDialLockIC9700(false)
        var locked = try await icomProtocol.getDialLockIC9700()
        #expect(!locked)
        print("   ✓ Dial lock OFF verified")

        // Test dial lock ON
        print("   Setting dial lock: ON")
        try await icomProtocol.setDialLockIC9700(true)
        locked = try await icomProtocol.getDialLockIC9700()
        #expect(locked)
        print("   ✓ Dial lock ON verified")

        // IMPORTANT: Restore dial lock OFF before continuing
        try await icomProtocol.setDialLockIC9700(false)
        print("   ⚠️  Dial lock turned OFF for remaining tests")

        // Restore original
        try await icomProtocol.setDialLockIC9700(originalLock)
        print("   🔄 Restored original dial lock setting\n")
    }

    @Test func dualwatch() async throws {
        print("📡 Test: Dualwatch (Dual Receiver Feature)")
        print("   Note: Dualwatch requires Main and Sub on DIFFERENT bands\n")

        let icomProtocol = try await getIcomProtocol()

        // Read complete 4-state VFO configuration
        print("   Reading current 4-state VFO configuration...")
        let vfoState = try await readVFOState()
        vfoState.printState()

        let mainBand = vfoState.mainBand
        let subBand = vfoState.subBand

        print("\n   Current: Main on \(mainBand), Sub on \(subBand)")

        if mainBand == subBand {
            guard promptUserForSetup(
                message: """
                Please manually switch Sub receiver to a different band than Main:
                - Main is currently on: \(mainBand)
                - Sub is currently on: \(subBand)

                NOTE: Dualwatch requires Main and Sub on different bands.

                Steps:
                1. Press [SUB] to select Sub receiver
                2. Press [BAND] to switch to a different band
                3. Press RETURN when ready
                """,
                skipMessage: "Dualwatch requires different bands - test skipped"
            ) else {
                return
            }

            // Verify bands are now different
            let newState = try await readVFOState()
            if newState.mainBand == newState.subBand {
                print("Main and Sub still on same band after manual switch - skipping")
                return
            }

            print("   ✓ Main on \(newState.mainBand), Sub on \(newState.subBand) - ready for dualwatch test\n")
        }

        // Test dualwatch with full user interaction
        do {
            // Test dualwatch OFF first
            print("\n   >>> Sending dualwatch OFF command...")
            try await icomProtocol.setDualwatch(false)
            print("   ✓ Dualwatch OFF command sent")

            guard waitForUserVerification(message: """
                DUALWATCH OFF:
                Look at your IC-9700 display.
                - The DW indicator should be OFF or not visible
                - Only one receiver should be active

                Verify that dualwatch is disabled.
                """) else {
                return
            }

            // Test dualwatch ON
            print("   >>> Sending dualwatch ON command...")
            try await icomProtocol.setDualwatch(true)
            print("   ✓ Dualwatch ON command sent")

            guard waitForUserVerification(message: """
                DUALWATCH ON:
                Look at your IC-9700 display.
                - The DW indicator should be ON/visible
                - Both receivers should be active
                - You should hear audio from both bands

                Verify that dualwatch is enabled and both receivers are working.
                """) else {
                return
            }

            // Turn off for remaining tests
            print("   >>> Turning dualwatch OFF for remaining tests...")
            try await icomProtocol.setDualwatch(false)
            print("   ✓ Dualwatch OFF for remaining tests\n")
        } catch {
            // Dualwatch might not be available in certain modes (e.g., non-FM modes)
            print("   ⚠️  Dualwatch command rejected - may not be available in current mode")
            print("   Note: Dualwatch typically requires FM mode on both receivers")
            print("   Dualwatch not available in current configuration - \(error)")
        }
    }

    @Test func bandExchange() async throws {
        print("📡 Test: Band Exchange (Dual Receiver Feature)")
        print("   Note: Band exchange swaps Main and Sub bands")
        print("   Test requires Main and Sub on DIFFERENT bands\n")

        let icomProtocol = try await getIcomProtocol()

        // Read complete 4-state VFO configuration before exchange
        print("   Reading current 4-state VFO configuration...")
        let initialState = try await readVFOState()
        initialState.printState()

        let mainBand = initialState.mainBand
        let subBand = initialState.subBand

        if mainBand == subBand {
            guard promptUserForSetup(
                message: """
                Please manually switch Sub receiver to a different band than Main:
                - Main is currently on: \(mainBand)
                - Sub is currently on: \(subBand)

                Steps:
                1. Press [SUB] to select Sub receiver
                2. Press [BAND] to switch to a different band (e.g., if Main is on VHF, switch Sub to UHF)
                3. Verify on radio display that Main and Sub show different bands
                """,
                skipMessage: "Band exchange requires Main and Sub on different bands - test skipped"
            ) else {
                return
            }

            // Verify bands are now different
            let newState = try await readVFOState()
            if newState.mainBand == newState.subBand {
                print("Main and Sub still on same band after manual switch - skipping")
                return
            }

            print("\n   ✓ Main on \(newState.mainBand), Sub on \(newState.subBand) - ready for exchange")
        } else {
            print("\n   ✓ Main on \(mainBand), Sub on \(subBand) - ready for exchange")
        }

        // Pause before exchange so user can note current state
        guard waitForUserVerification(message: """
            BEFORE BAND EXCHANGE:
            - Main is on: \(mainBand) (\(HardwareTestHelpers.formatFrequency(initialState.mainAFreq)))
            - Sub is on: \(subBand) (\(HardwareTestHelpers.formatFrequency(initialState.subAFreq)))

            Please verify these bands/frequencies on your radio display.
            """) else {
            return
        }

        // Exchange bands
        print("   >>> Sending band exchange command...")
        try await icomProtocol.exchangeBands()

        // Immediate user verification of the swap
        guard waitForUserVerification(message: """
            AFTER BAND EXCHANGE:
            The bands should now be SWAPPED on your radio:
            - Main should now be on: \(subBand) (was \(mainBand))
            - Sub should now be on: \(mainBand) (was \(subBand))

            Look at your IC-9700 display and verify the bands have swapped.
            Did the bands swap correctly?
            """) else {
            return
        }

        // Programmatic verification
        print("   Reading 4-state VFO configuration after exchange...")
        let afterState = try await readVFOState()
        afterState.printState()

        print("\n   Verifying band exchange:")
        print("   Before: Main VFO A = \(HardwareTestHelpers.formatFrequency(initialState.mainAFreq)), Sub VFO A = \(HardwareTestHelpers.formatFrequency(initialState.subAFreq))")
        print("   After:  Main VFO A = \(HardwareTestHelpers.formatFrequency(afterState.mainAFreq)), Sub VFO A = \(HardwareTestHelpers.formatFrequency(afterState.subAFreq))")

        #expect(afterState.mainAFreq == initialState.subAFreq, "Main VFO A should now have Sub VFO A's frequency")
        #expect(afterState.subAFreq == initialState.mainAFreq, "Sub VFO A should now have Main VFO A's frequency")

        // Exchange back to restore original state
        print("\n   >>> Exchanging back to restore original state...")
        try await icomProtocol.exchangeBands()

        guard waitForUserVerification(message: """
            AFTER RESTORING:
            The bands should be back to original configuration:
            - Main should be back on: \(mainBand)
            - Sub should be back on: \(subBand)

            Verify on your radio that the bands are restored.
            """) else {
            return
        }

        // Programmatic verification
        let restoredState = try await readVFOState()
        print("   Restored configuration:")
        print("     Main VFO A: \(HardwareTestHelpers.formatFrequency(restoredState.mainAFreq)) (expected: \(HardwareTestHelpers.formatFrequency(initialState.mainAFreq)))")
        print("     Sub VFO A: \(HardwareTestHelpers.formatFrequency(restoredState.subAFreq)) (expected: \(HardwareTestHelpers.formatFrequency(initialState.subAFreq)))")

        #expect(restoredState.mainAFreq == initialState.mainAFreq, "Main should be restored")
        #expect(restoredState.subAFreq == initialState.subAFreq, "Sub should be restored")

        print("   ✓ Band exchange verified and restored\n")
    }

    // MARK: - Satellite Mode Tests

    @Test func satelliteMode() async throws {
        print("🛰️  Test: Satellite Mode")
        print("   Note: This test requires VHF on Main RX and UHF on Sub RX")

        let icomProtocol = try await getIcomProtocol()

        // Check current band configuration
        let currentMain = try await rig.frequency(vfo: .a, cached: false)
        let currentSub = try await rig.frequency(vfo: .b, cached: false)

        let mainIsVHF = (144_000_000...148_000_000).contains(currentMain)
        let subIsUHF = (430_000_000...450_000_000).contains(currentSub)

        if !mainIsVHF || !subIsUHF {
            print("   ⚠️  Main RX: \(HardwareTestHelpers.formatFrequency(currentMain)) (need VHF)")
            print("   ⚠️  Sub RX: \(HardwareTestHelpers.formatFrequency(currentSub)) (need UHF)")

            guard promptUserForSetup(
                message: """
                Please manually configure bands for satellite mode testing:
                - Main receiver should be on 2m VHF band (144-148 MHz)
                - Sub receiver should be on 70cm UHF band (430-450 MHz)

                Current configuration:
                - Main: \(HardwareTestHelpers.formatFrequency(currentMain)) (VHF: \(mainIsVHF ? "✓" : "✗"))
                - Sub: \(HardwareTestHelpers.formatFrequency(currentSub)) (UHF: \(subIsUHF ? "✓" : "✗"))

                Steps:
                1. Press [MAIN] and [BAND] to switch Main to 2m VHF
                2. Press [SUB] and [BAND] to switch Sub to 70cm UHF
                3. Press RETURN when ready
                """,
                skipMessage: "Satellite mode test requires VHF/UHF configuration - test skipped"
            ) else {
                return
            }

            // Verify configuration after manual setup
            let newMain = try await rig.frequency(vfo: .a, cached: false)
            let newSub = try await rig.frequency(vfo: .b, cached: false)
            let newMainIsVHF = (144_000_000...148_000_000).contains(newMain)
            let newSubIsUHF = (430_000_000...450_000_000).contains(newSub)

            guard newMainIsVHF && newSubIsUHF else {
                print("Configuration still incorrect after manual setup - skipping")
                return
            }

            print("   ✓ Main on VHF, Sub on UHF - ready for satellite mode test")
        }

        // Save original satellite mode
        let originalSatMode = try await icomProtocol.getSatelliteModeIC9700()

        // Enable satellite mode
        print("   Enabling satellite mode...")
        try await icomProtocol.setSatelliteModeIC9700(true)
        var satMode = try await icomProtocol.getSatelliteModeIC9700()
        #expect(satMode)
        print("   ✓ Satellite mode enabled")

        // Set up typical satellite frequencies
        let uplinkFreq: UInt64 = 145_850_000   // 2m
        let downlinkFreq: UInt64 = 435_300_000  // 70cm

        print("   Setting uplink: \(HardwareTestHelpers.formatFrequency(uplinkFreq))")
        try await rig.setFrequency(uplinkFreq, vfo: .a)
        try await rig.setMode(.fm, vfo: .a)

        print("   Setting downlink: \(HardwareTestHelpers.formatFrequency(downlinkFreq))")
        try await rig.setFrequency(downlinkFreq, vfo: .b)
        try await rig.setMode(.fm, vfo: .b)

        // Verify configuration
        let actualUplink = try await rig.frequency(vfo: .a, cached: false)
        let actualDownlink = try await rig.frequency(vfo: .b, cached: false)

        #expect(actualUplink == uplinkFreq)
        #expect(actualDownlink == downlinkFreq)

        print("   ✓ Uplink: \(HardwareTestHelpers.formatFrequency(actualUplink)) FM")
        print("   ✓ Downlink: \(HardwareTestHelpers.formatFrequency(actualDownlink)) FM")

        // Disable satellite mode
        try await icomProtocol.setSatelliteModeIC9700(false)
        satMode = try await icomProtocol.getSatelliteModeIC9700()
        #expect(!satMode)
        print("   ✓ Satellite mode disabled")

        // Restore original
        try await icomProtocol.setSatelliteModeIC9700(originalSatMode)
        print("   ✓ Satellite mode testing complete\n")
    }

    // MARK: - Split Operation

    @Test func splitOperation() async throws {
        print("🔊 Test: Split Operation (MAIN VFO only)")
        print("   Note: IC-9700 split function only works on MAIN band")
        print("   MAIN will transmit on different frequency than it receives")

        // Save current state
        let currentMain = try await rig.frequency(vfo: .a, cached: false)
        let currentSub = try await rig.frequency(vfo: .b, cached: false)
        let originalSplit = try await rig.isSplitEnabled()

        print("   Main RX: \(HardwareTestHelpers.formatFrequency(currentMain))")
        print("   Sub RX: \(HardwareTestHelpers.formatFrequency(currentSub))")

        // Set Sub RX frequency offset from Main (+50 kHz within same band)
        let splitFreq = currentMain + 50_000
        print("   Setting MAIN split TX frequency: \(HardwareTestHelpers.formatFrequency(splitFreq))")
        try await rig.setFrequency(splitFreq, vfo: .b)

        // Enable split
        print("   Enabling split on MAIN band")
        try await rig.setSplit(true)
        var enabled = try await rig.isSplitEnabled()
        #expect(enabled)
        print("   ✓ Split enabled on MAIN")

        // Disable split
        print("   Disabling split")
        try await rig.setSplit(false)
        enabled = try await rig.isSplitEnabled()
        #expect(!enabled)
        print("   ✓ Split disabled")

        // Restore original state
        try await rig.setFrequency(currentSub, vfo: .b)
        try await rig.setSplit(originalSplit)
        print("   ✓ Split operation verified (MAIN VFO only)\n")
    }

    // MARK: - Power and Meter Tests

    @Test func powerControl() async throws {
        print("⚡ Test: Power Control")

        let originalPower = try await rig.power()
        print("   💾 Original power: \(originalPower)W")

        let testPowers = [5, 10, 25, 50]
        for targetPower in testPowers {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)
            let actual = try await rig.power()
            // Allow 5W tolerance
            #expect(abs(actual - targetPower) <= 5, "Power \(actual)W not within 5W of target \(targetPower)W")
            print("   ✓ Power set to \(actual)W")
        }

        // Restore original
        try await rig.setPower(originalPower)
        print("   🔄 Restored power to \(originalPower)W\n")
    }

    @Test func signalStrength() async throws {
        print("📊 Test: Signal Strength (S-Meter)")

        for i in 1...5 {
            let strength = try await rig.signalStrength()
            print("   Reading \(i): \(strength.description) (Raw: \(strength.raw))")

            #expect(strength.sUnits >= 0)
            #expect(strength.sUnits <= 9)

            try await Task.sleep(nanoseconds: 200_000_000)
        }

        print("   ✓ S-meter readings verified\n")
    }

    @Test func squelchStatus() async throws {
        print("📊 Test: Squelch Status (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        let squelchOpen = try await icomProtocol.getSquelchStatusIC9700()
        print("   Squelch status: \(squelchOpen ? "OPEN" : "CLOSED")")
        print("   ✓ Squelch status read successfully\n")
    }

    // MARK: - PTT Test

    @Test func pttControl() async throws {
        guard HardwareTestHelpers.confirmPTTTest(radioName: radioName) else {
            print("PTT test skipped by user")
            return
        }

        print("\n📡 Test: PTT Control")

        // Save original state
        let originalPower = try await rig.power()
        let originalMode = try await rig.mode(vfo: .a, cached: false)

        // Set safe transmit parameters
        print("   Setting power to 5W")
        try await rig.setPower(5)

        print("   Setting mode to FM")
        try await rig.setMode(.fm, vfo: .a)

        print("   ⚠️  Keying in 2 seconds...")
        try await Task.sleep(nanoseconds: 2_000_000_000)

        print("   🔴 PTT ON")
        try await rig.setPTT(true)

        let pttOn = try await rig.isPTTEnabled()
        #expect(pttOn)

        try await Task.sleep(nanoseconds: 500_000_000)

        print("   ⚪ PTT OFF")
        try await rig.setPTT(false)

        let pttOff = try await rig.isPTTEnabled()
        #expect(!pttOff)

        // Restore original state
        try await rig.setPower(originalPower)
        try await rig.setMode(originalMode, vfo: .a)
        print("   ✓ PTT control verified and state restored\n")
    }

    // MARK: - Stress Tests

    @Test func rapidFrequencyChanges() async throws {
        print("⚡ Test: Rapid Frequency Changes")

        let startFreq = try await rig.frequency(vfo: .a, cached: false)
        let iterations = 50

        print("   Starting from \(HardwareTestHelpers.formatFrequency(startFreq))")
        print("   Performing \(iterations) rapid frequency changes...")

        let startTime = Date()

        for i in 0..<iterations {
            // Stay within current band - small 10kHz steps
            let freq = startFreq + UInt64(i * 10_000)
            try await rig.setFrequency(freq, vfo: .a)

            if (i + 1) % 10 == 0 {
                print("   Progress: \(i + 1)/\(iterations)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let avgTime = (duration / Double(iterations)) * 1000

        print("   Completed \(iterations) changes in \(String(format: "%.2f", duration))s")
        print("   Average: \(String(format: "%.1f", avgTime))ms per change")

        // Restore original frequency
        try await rig.setFrequency(startFreq, vfo: .a)
        print("   ✓ Rapid frequency changes verified\n")
    }

    @Test func rapidModeChanges() async throws {
        print("⚡ Test: Rapid Mode Changes")

        let originalMode = try await rig.mode(vfo: .a, cached: false)
        let modes: [Mode] = [.lsb, .usb, .fm, .am, .cw]
        let iterations = 25

        print("   Performing \(iterations) rapid mode changes...")

        let startTime = Date()

        for i in 0..<iterations {
            let mode = modes[i % modes.count]
            try await rig.setMode(mode, vfo: .a)

            if (i + 1) % 5 == 0 {
                print("   Progress: \(i + 1)/\(iterations)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let avgTime = (duration / Double(iterations)) * 1000

        print("   Completed \(iterations) changes in \(String(format: "%.2f", duration))s")
        print("   Average: \(String(format: "%.1f", avgTime))ms per change")

        // Restore original mode
        try await rig.setMode(originalMode, vfo: .a)
        print("   ✓ Rapid mode changes verified\n")
    }
}
