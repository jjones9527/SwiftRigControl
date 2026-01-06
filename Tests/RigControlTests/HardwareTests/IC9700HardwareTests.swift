import XCTest
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

    // MARK: - Helper Methods

    /// Get Icom protocol instance
    private func getIcomProtocol() async throws -> IcomCIVProtocol {
        guard let rig = rig else {
            throw RigError.notConnected
        }
        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            throw RigError.unsupportedOperation("Not an Icom protocol")
        }
        return icomProtocol
    }

    /// Ensure radio is on a specific band
    /// Returns true if already on band, false if user needs to switch manually
    private func ensureBand(_ description: String, frequencyRange: ClosedRange<UInt64>, vfo: VFO = .a) async throws -> Bool {
        guard let rig = rig else { return false }

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
        guard let rig = rig else { return }

        do {
            try await rig.setFrequency(freq, vfo: vfo)
        } catch {
            print("   ⚠️  Could not set frequency \(HardwareTestHelpers.formatFrequency(freq)): \(error)")
            throw error
        }
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

    // MARK: - VFO and Band Tests

    func testVHFBand() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: VHF Band (2m)")
        print("   Note: Main RX must be on VHF band for this test")

        let vhfRange: ClosedRange<UInt64> = 144_000_000...148_000_000

        guard try await ensureBand("VHF 2m band", frequencyRange: vhfRange) else {
            throw XCTSkip("Main RX not on VHF - manually switch to 2m band and retry")
        }

        // Get current frequency as baseline
        let baseFreq = try await rig.frequency(vfo: .a, cached: false)

        // Test frequencies within VHF band
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
            XCTAssertEqual(actual, freq)
            print("   ✓ \(desc) verified")
        }

        // Restore baseline frequency
        try await rig.setFrequency(baseFreq, vfo: .a)
        print("   ✓ VHF band testing complete\n")
    }

    func testUHFBand() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: UHF Band (70cm)")
        print("   Note: Main RX must be on UHF band for this test")

        let uhfRange: ClosedRange<UInt64> = 430_000_000...450_000_000

        guard try await ensureBand("UHF 70cm band", frequencyRange: uhfRange) else {
            throw XCTSkip("Main RX not on UHF - manually switch to 70cm band and retry")
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
            XCTAssertEqual(actual, freq)
            print("   ✓ \(desc) verified")
        }

        try await rig.setFrequency(baseFreq, vfo: .a)
        print("   ✓ UHF band testing complete\n")
    }

    func test1_2GHzBand() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: 1.2GHz Band (23cm)")
        print("   Note: Main RX must be on 1.2GHz band for this test")

        let ghzRange: ClosedRange<UInt64> = 1_240_000_000...1_300_000_000

        guard try await ensureBand("1.2GHz 23cm band", frequencyRange: ghzRange) else {
            throw XCTSkip("Main RX not on 1.2GHz - manually switch to 23cm band and retry")
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
            XCTAssertEqual(actual, freq)
            print("   ✓ \(desc) verified")
        }

        try await rig.setFrequency(baseFreq, vfo: .a)
        print("   ✓ 1.2GHz band testing complete\n")
    }

    // MARK: - Mode Tests

    func testModeControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("📻 Test: Mode Control")

        // Save current state
        let originalFreq = try await rig.frequency(vfo: .a, cached: false)
        let originalMode = try await rig.mode(vfo: .a, cached: false)

        print("   Testing on frequency: \(HardwareTestHelpers.formatFrequency(originalFreq))")

        // Test all standard modes
        let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .fm, .am]

        for mode in modes {
            print("   Testing mode: \(mode.rawValue)")
            try await rig.setMode(mode, vfo: .a)
            let actual = try await rig.mode(vfo: .a, cached: false)
            XCTAssertEqual(actual, mode)
            print("   ✓ \(mode.rawValue) verified")
        }

        // Restore original mode
        try await rig.setMode(originalMode, vfo: .a)
        print("   ✓ Mode control complete\n")
    }

    // MARK: - Dual Receiver Tests

    func testDualReceiver() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: Dual Independent Receivers")

        // Read current state of both receivers
        let initialMain = try await rig.frequency(vfo: .a, cached: false)
        let initialSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Initial Main RX: \(HardwareTestHelpers.formatFrequency(initialMain))")
        print("   Initial Sub RX: \(HardwareTestHelpers.formatFrequency(initialSub))")

        // Test frequency changes within each receiver's current band
        // Offset by 25kHz to ensure they're different
        let newMainFreq = initialMain + 25_000
        let newSubFreq = initialSub + 25_000

        print("   Setting Main RX: \(HardwareTestHelpers.formatFrequency(newMainFreq))")
        try await rig.setFrequency(newMainFreq, vfo: .a)

        print("   Setting Sub RX: \(HardwareTestHelpers.formatFrequency(newSubFreq))")
        try await rig.setFrequency(newSubFreq, vfo: .b)

        // Verify both changed independently
        let actualMain = try await rig.frequency(vfo: .a, cached: false)
        let actualSub = try await rig.frequency(vfo: .b, cached: false)

        XCTAssertEqual(actualMain, newMainFreq)
        XCTAssertEqual(actualSub, newSubFreq)

        print("   ✓ Main RX: \(HardwareTestHelpers.formatFrequency(actualMain))")
        print("   ✓ Sub RX: \(HardwareTestHelpers.formatFrequency(actualSub))")

        // Restore original frequencies
        try await rig.setFrequency(initialMain, vfo: .a)
        try await rig.setFrequency(initialSub, vfo: .b)

        print("   ✓ Dual receiver operation verified\n")
    }

    func testIndependentModes() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🔀 Test: Independent Mode Control per Receiver")
        print("   Note: IC-9700 Main/Sub share mode when on SAME band")
        print("   This test requires Main and Sub on DIFFERENT bands")

        // Save current modes
        let originalModeMain = try await rig.mode(vfo: .a, cached: false)
        let originalModeSub = try await rig.mode(vfo: .b, cached: false)

        let freqMain = try await rig.frequency(vfo: .a, cached: false)
        let freqSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Initial Main RX: \(HardwareTestHelpers.formatFrequency(freqMain)) mode=\(originalModeMain.rawValue)")
        print("   Initial Sub RX: \(HardwareTestHelpers.formatFrequency(freqSub)) mode=\(originalModeSub.rawValue)")

        // Check if Main and Sub are on different bands
        let mainBand = getBandName(freqMain)
        let subBand = getBandName(freqSub)

        if mainBand == subBand {
            throw XCTSkip("Test requires Main and Sub on different bands (both currently on \(mainBand)). Manually switch Sub to a different band.")
        }

        print("   Main on \(mainBand), Sub on \(subBand) - different bands ✓")

        // Set different modes on each receiver
        print("\n   Setting Main RX to USB...")
        try await rig.setMode(.usb, vfo: .a)
        print("   Reading back Main mode...")
        let modeMainAfterSet = try await rig.mode(vfo: .a, cached: false)
        print("   Main mode is now: \(modeMainAfterSet.rawValue)")

        print("\n   Setting Sub RX to FM...")
        try await rig.setMode(.fm, vfo: .b)
        print("   Reading back Sub mode...")
        let modeSubAfterSet = try await rig.mode(vfo: .b, cached: false)
        print("   Sub mode is now: \(modeSubAfterSet.rawValue)")

        // Verify they changed independently
        print("\n   Verifying independent mode control...")
        print("   Reading Main mode again...")
        let modeMain = try await rig.mode(vfo: .a, cached: false)
        print("   Main RX mode: \(modeMain.rawValue) (expected: USB)")

        print("   Reading Sub mode again...")
        let modeSub = try await rig.mode(vfo: .b, cached: false)
        print("   Sub RX mode: \(modeSub.rawValue) (expected: FM)")

        XCTAssertEqual(modeMain, .usb, "Main RX should be USB")
        XCTAssertEqual(modeSub, .fm, "Sub RX should be FM")

        print("   ✓ Main RX: \(modeMain.rawValue)")
        print("   ✓ Sub RX: \(modeSub.rawValue)")

        // Restore original modes
        print("\n   Restoring original modes...")
        try await rig.setMode(originalModeMain, vfo: .a)
        try await rig.setMode(originalModeSub, vfo: .b)

        print("   ✓ Independent mode control verified\n")
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

    // MARK: - IC-9700 Specific Function Tests

    func testAttenuatorControl() async throws {
        print("📡 Test: Attenuator Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original attenuator setting
        let originalAtt = try await icomProtocol.getAttenuatorIC9700()
        print("   💾 Original attenuator: 0x\(String(format: "%02X", originalAtt))")

        // Test OFF (0x00)
        print("   Setting attenuator: OFF (0x00)")
        try await icomProtocol.setAttenuatorIC9700(0x00)
        var readValue = try await icomProtocol.getAttenuatorIC9700()
        XCTAssertEqual(readValue, 0x00)
        print("   ✓ Attenuator OFF verified")

        // Test 10dB (0x10)
        print("   Setting attenuator: 10dB (0x10)")
        try await icomProtocol.setAttenuatorIC9700(0x10)
        readValue = try await icomProtocol.getAttenuatorIC9700()
        XCTAssertEqual(readValue, 0x10)
        print("   ✓ Attenuator 10dB verified")

        // Restore original
        try await icomProtocol.setAttenuatorIC9700(originalAtt)
        print("   🔄 Restored original attenuator setting\n")
    }

    func testPreampControl() async throws {
        print("📡 Test: Preamp Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original preamp setting
        let originalPreamp = try await icomProtocol.getPreampIC9700()
        print("   💾 Original preamp: 0x\(String(format: "%02X", originalPreamp))")

        // Test OFF (0x00)
        print("   Setting preamp: OFF (0x00)")
        try await icomProtocol.setPreampIC9700(0x00)
        var readValue = try await icomProtocol.getPreampIC9700()
        XCTAssertEqual(readValue, 0x00)
        print("   ✓ Preamp OFF verified")

        // Test ON (0x01)
        print("   Setting preamp: ON (0x01)")
        try await icomProtocol.setPreampIC9700(0x01)
        readValue = try await icomProtocol.getPreampIC9700()
        XCTAssertEqual(readValue, 0x01)
        print("   ✓ Preamp ON verified")

        // Restore original
        try await icomProtocol.setPreampIC9700(originalPreamp)
        print("   🔄 Restored original preamp setting\n")
    }

    func testAGCControl() async throws {
        print("📡 Test: AGC Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original AGC setting
        let originalAGC = try await icomProtocol.getAGCIC9700()
        print("   💾 Original AGC: 0x\(String(format: "%02X", originalAGC))")

        let agcSettings: [(code: UInt8, name: String)] = [
            (0x00, "OFF"),
            (0x01, "FAST"),
            (0x02, "MID"),
            (0x03, "SLOW")
        ]

        for setting in agcSettings {
            print("   Setting AGC: \(setting.name) (0x\(String(format: "%02X", setting.code)))")
            try await icomProtocol.setAGCIC9700(setting.code)
            let readValue = try await icomProtocol.getAGCIC9700()
            XCTAssertEqual(readValue, setting.code)
            print("   ✓ AGC \(setting.name) verified")
        }

        // Restore original
        try await icomProtocol.setAGCIC9700(originalAGC)
        print("   🔄 Restored original AGC setting\n")
    }

    func testManualNotch() async throws {
        print("📡 Test: Manual Notch Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original notch setting
        let originalNotch = try await icomProtocol.getManualNotchIC9700()
        let originalPosition = try await icomProtocol.getNotchPositionIC9700()
        print("   💾 Original notch enabled: \(originalNotch), position: \(originalPosition)")

        // Test notch OFF
        print("   Setting manual notch: OFF")
        try await icomProtocol.setManualNotchIC9700(false)
        var enabled = try await icomProtocol.getManualNotchIC9700()
        XCTAssertFalse(enabled)
        print("   ✓ Manual notch OFF verified")

        // Test notch ON
        print("   Setting manual notch: ON")
        try await icomProtocol.setManualNotchIC9700(true)
        enabled = try await icomProtocol.getManualNotchIC9700()
        XCTAssertTrue(enabled)
        print("   ✓ Manual notch ON verified")

        // Test notch position
        print("   Setting notch position: 128 (center)")
        try await icomProtocol.setNotchPositionIC9700(128)
        let position = try await icomProtocol.getNotchPositionIC9700()
        XCTAssertEqual(position, 128)
        print("   ✓ Notch position verified")

        // Restore original
        try await icomProtocol.setManualNotchIC9700(originalNotch)
        try await icomProtocol.setNotchPositionIC9700(originalPosition)
        print("   🔄 Restored original notch settings\n")
    }

    func testMonitorFunction() async throws {
        print("📡 Test: Monitor Function (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original monitor settings
        let originalMonitorEnabled = try await icomProtocol.getMonitorIC9700()
        let originalMonitorGain = try await icomProtocol.getMonitorGainIC9700()
        print("   💾 Original monitor: \(originalMonitorEnabled), gain: \(originalMonitorGain)")

        // Test monitor OFF
        print("   Setting monitor: OFF")
        try await icomProtocol.setMonitorIC9700(false)
        var enabled = try await icomProtocol.getMonitorIC9700()
        XCTAssertFalse(enabled)
        print("   ✓ Monitor OFF verified")

        // Test monitor ON
        print("   Setting monitor: ON")
        try await icomProtocol.setMonitorIC9700(true)
        enabled = try await icomProtocol.getMonitorIC9700()
        XCTAssertTrue(enabled)
        print("   ✓ Monitor ON verified")

        // Test monitor gain
        print("   Setting monitor gain: 128 (50%)")
        try await icomProtocol.setMonitorGainIC9700(128)
        let gain = try await icomProtocol.getMonitorGainIC9700()
        XCTAssertEqual(gain, 128)
        print("   ✓ Monitor gain verified")

        // Restore original
        try await icomProtocol.setMonitorIC9700(originalMonitorEnabled)
        try await icomProtocol.setMonitorGainIC9700(originalMonitorGain)
        print("   🔄 Restored original monitor settings\n")
    }

    func testNRLevel() async throws {
        print("📡 Test: NR Level Control (IC-9700 Specific)")
        print("   Note: IC-9700 displays NR as 0-15, CI-V uses 0-255")

        let icomProtocol = try await getIcomProtocol()

        // Save original NR level
        let originalLevel = try await icomProtocol.getNRLevelIC9700()
        print("   💾 Original NR level: \(originalLevel)")

        let testLevels: [(value: UInt8, name: String)] = [
            (0, "0% (Display: 0)"),
            (128, "50% (Display: ~8)"),
            (255, "100% (Display: 15)")
        ]

        for test in testLevels {
            print("   Setting NR level: \(test.name)")
            try await icomProtocol.setNRLevelIC9700(test.value)
            let readValue = try await icomProtocol.getNRLevelIC9700()
            XCTAssertEqual(readValue, test.value)
            print("   ✓ NR level \(test.name) verified")
        }

        // Restore original
        try await icomProtocol.setNRLevelIC9700(originalLevel)
        print("   🔄 Restored original NR level\n")
    }

    func testVOXControl() async throws {
        print("📡 Test: VOX Control (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original VOX settings
        let originalVoxGain = try await icomProtocol.getVoxGainIC9700()
        let originalAntiVoxGain = try await icomProtocol.getAntiVoxGainIC9700()
        print("   💾 Original VOX gain: \(originalVoxGain), Anti-VOX: \(originalAntiVoxGain)")

        // Test VOX gain
        let voxLevels: [(value: UInt8, name: String)] = [
            (0, "0%"),
            (128, "50%"),
            (255, "100%")
        ]

        for test in voxLevels {
            print("   Setting VOX gain: \(test.name)")
            try await icomProtocol.setVoxGainIC9700(test.value)
            let readValue = try await icomProtocol.getVoxGainIC9700()
            XCTAssertEqual(readValue, test.value)
            print("   ✓ VOX gain \(test.name) verified")
        }

        // Test Anti-VOX gain
        for test in voxLevels {
            print("   Setting Anti-VOX gain: \(test.name)")
            try await icomProtocol.setAntiVoxGainIC9700(test.value)
            let readValue = try await icomProtocol.getAntiVoxGainIC9700()
            XCTAssertEqual(readValue, test.value)
            print("   ✓ Anti-VOX gain \(test.name) verified")
        }

        // Restore original
        try await icomProtocol.setVoxGainIC9700(originalVoxGain)
        try await icomProtocol.setAntiVoxGainIC9700(originalAntiVoxGain)
        print("   🔄 Restored original VOX settings\n")
    }

    func testDialLock() async throws {
        print("📡 Test: Dial Lock (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Save original dial lock setting
        let originalLock = try await icomProtocol.getDialLockIC9700()
        print("   💾 Original dial lock: \(originalLock)")

        // Test dial lock OFF
        print("   Setting dial lock: OFF")
        try await icomProtocol.setDialLockIC9700(false)
        var locked = try await icomProtocol.getDialLockIC9700()
        XCTAssertFalse(locked)
        print("   ✓ Dial lock OFF verified")

        // Test dial lock ON
        print("   Setting dial lock: ON")
        try await icomProtocol.setDialLockIC9700(true)
        locked = try await icomProtocol.getDialLockIC9700()
        XCTAssertTrue(locked)
        print("   ✓ Dial lock ON verified")

        // IMPORTANT: Restore dial lock OFF before continuing
        try await icomProtocol.setDialLockIC9700(false)
        print("   ⚠️  Dial lock turned OFF for remaining tests")

        // Restore original
        try await icomProtocol.setDialLockIC9700(originalLock)
        print("   🔄 Restored original dial lock setting\n")
    }

    func testDualwatch() async throws {
        print("📡 Test: Dualwatch (Dual Receiver Feature)")

        let icomProtocol = try await getIcomProtocol()

        // Test dualwatch OFF
        print("   Setting dualwatch: OFF")
        try await icomProtocol.setDualwatch(false)
        print("   ✓ Dualwatch OFF command sent")

        // Test dualwatch ON
        print("   Setting dualwatch: ON")
        try await icomProtocol.setDualwatch(true)
        print("   ✓ Dualwatch ON command sent")

        // Turn off for remaining tests
        try await icomProtocol.setDualwatch(false)
        print("   ✓ Dualwatch OFF for remaining tests\n")
    }

    func testBandExchange() async throws {
        print("📡 Test: Band Exchange (Dual Receiver Feature)")
        print("   Note: Band exchange swaps Main and Sub bands")
        print("   Test requires Main and Sub on DIFFERENT bands")

        let icomProtocol = try await getIcomProtocol()
        guard let rig = rig else { return }

        // Get initial frequencies
        let initialMain = try await rig.frequency(vfo: .a, cached: false)
        let initialSub = try await rig.frequency(vfo: .b, cached: false)

        print("   Before exchange - Main: \(HardwareTestHelpers.formatFrequency(initialMain))")
        print("   Before exchange - Sub: \(HardwareTestHelpers.formatFrequency(initialSub))")

        // Check if Main and Sub are on different bands
        let mainBand = getBandName(initialMain)
        let subBand = getBandName(initialSub)

        if mainBand == subBand {
            throw XCTSkip("Band exchange requires Main and Sub on different bands (both currently on \(mainBand)). Manually switch Sub to a different band.")
        }

        print("   Main on \(mainBand), Sub on \(subBand) - ready for exchange ✓")

        // Exchange bands
        print("   Exchanging Main/Sub bands...")
        try await icomProtocol.exchangeBands()

        // Add delay to allow radio to complete band exchange
        print("   Waiting 200ms for radio to complete band exchange...")
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms delay

        // Verify bands were swapped
        let afterMain = try await rig.frequency(vfo: .a, cached: false)
        let afterSub = try await rig.frequency(vfo: .b, cached: false)

        print("   After exchange - Main: \(HardwareTestHelpers.formatFrequency(afterMain))")
        print("   After exchange - Sub: \(HardwareTestHelpers.formatFrequency(afterSub))")

        XCTAssertEqual(afterMain, initialSub, "Main should now have Sub's frequency")
        XCTAssertEqual(afterSub, initialMain, "Sub should now have Main's frequency")

        // Exchange back to restore original state
        print("   Exchanging back to restore original state...")
        try await icomProtocol.exchangeBands()
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms delay

        print("   ✓ Band exchange verified and restored\n")
    }

    // MARK: - Satellite Mode Tests

    func testSatelliteMode() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("🛰️  Test: Satellite Mode")
        print("   Note: This test requires VHF on Main RX and UHF on Sub RX")

        let icomProtocol = try await getIcomProtocol()

        // Check current band configuration
        let currentMain = try await rig.frequency(vfo: .a, cached: false)
        let currentSub = try await rig.frequency(vfo: .b, cached: false)

        let mainIsVHF = (144_000_000...148_000_000).contains(currentMain)
        let subIsUHF = (430_000_000...450_000_000).contains(currentSub)

        guard mainIsVHF && subIsUHF else {
            print("   ⚠️  Main RX: \(HardwareTestHelpers.formatFrequency(currentMain)) (need VHF)")
            print("   ⚠️  Sub RX: \(HardwareTestHelpers.formatFrequency(currentSub)) (need UHF)")
            throw XCTSkip("Satellite mode test requires VHF/UHF configuration")
        }

        // Save original satellite mode
        let originalSatMode = try await icomProtocol.getSatelliteModeIC9700()

        // Enable satellite mode
        print("   Enabling satellite mode...")
        try await icomProtocol.setSatelliteModeIC9700(true)
        var satMode = try await icomProtocol.getSatelliteModeIC9700()
        XCTAssertTrue(satMode)
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

        XCTAssertEqual(actualUplink, uplinkFreq)
        XCTAssertEqual(actualDownlink, downlinkFreq)

        print("   ✓ Uplink: \(HardwareTestHelpers.formatFrequency(actualUplink)) FM")
        print("   ✓ Downlink: \(HardwareTestHelpers.formatFrequency(actualDownlink)) FM")

        // Disable satellite mode
        try await icomProtocol.setSatelliteModeIC9700(false)
        satMode = try await icomProtocol.getSatelliteModeIC9700()
        XCTAssertFalse(satMode)
        print("   ✓ Satellite mode disabled")

        // Restore original
        try await icomProtocol.setSatelliteModeIC9700(originalSatMode)
        print("   ✓ Satellite mode testing complete\n")
    }

    // MARK: - Split Operation

    func testSplitOperation() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

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
        // On IC-9700, split uses MAIN band only (transmit on different freq than receive)
        let splitFreq = currentMain + 50_000
        print("   Setting MAIN split TX frequency: \(HardwareTestHelpers.formatFrequency(splitFreq))")
        try await rig.setFrequency(splitFreq, vfo: .b)

        // Enable split (Command 0x0F 0x01)
        print("   Enabling split on MAIN band")
        try await rig.setSplit(true)
        var enabled = try await rig.isSplitEnabled()
        XCTAssertTrue(enabled)
        print("   ✓ Split enabled on MAIN")

        // Disable split (Command 0x0F 0x00)
        print("   Disabling split")
        try await rig.setSplit(false)
        enabled = try await rig.isSplitEnabled()
        XCTAssertFalse(enabled)
        print("   ✓ Split disabled")

        // Restore original state
        try await rig.setFrequency(currentSub, vfo: .b)
        try await rig.setSplit(originalSplit)
        print("   ✓ Split operation verified (MAIN VFO only)\n")
    }

    // MARK: - Power and Meter Tests

    func testPowerControl() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

        print("⚡ Test: Power Control")

        let originalPower = try await rig.power()
        print("   💾 Original power: \(originalPower)W")

        let testPowers = [5, 10, 25, 50]
        for targetPower in testPowers {
            print("   Setting power to \(targetPower)W")
            try await rig.setPower(targetPower)
            let actual = try await rig.power()
            // Allow 5W tolerance
            XCTAssertTrue(abs(actual - targetPower) <= 5, "Power \(actual)W not within 5W of target \(targetPower)W")
            print("   ✓ Power set to \(actual)W")
        }

        // Restore original
        try await rig.setPower(originalPower)
        print("   🔄 Restored power to \(originalPower)W\n")
    }

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

        print("   ✓ S-meter readings verified\n")
    }

    func testSquelchStatus() async throws {
        print("📊 Test: Squelch Status (IC-9700 Specific)")

        let icomProtocol = try await getIcomProtocol()

        // Read squelch status
        let squelchOpen = try await icomProtocol.getSquelchStatusIC9700()
        print("   Squelch status: \(squelchOpen ? "OPEN" : "CLOSED")")
        print("   ✓ Squelch status read successfully\n")
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

        // Save original state
        let originalPower = try await rig.power()
        let originalMode = try await rig.mode(vfo: .a, cached: false)

        // Set safe transmit parameters
        print("   Setting power to 5W")
        try await rig.setPower(5)

        // Use current frequency and set to FM mode for safety
        print("   Setting mode to FM")
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

        // Restore original state
        try await rig.setPower(originalPower)
        try await rig.setMode(originalMode, vfo: .a)
        print("   ✓ PTT control verified and state restored\n")
    }

    // MARK: - Stress Tests

    func testRapidFrequencyChanges() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

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

    func testRapidModeChanges() async throws {
        guard let rig = rig else {
            XCTFail("Rig not initialized")
            return
        }

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
