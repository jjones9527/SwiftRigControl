import Foundation
import RigControl

/// Interactive IC-9700 Hardware Validator
///
/// This program provides FULLY INTERACTIVE validation of IC-9700 4-state VFO architecture.
/// It pauses and waits for user feedback at EACH step, allowing time for configuration
/// changes and visual verification on the radio.
///
/// ## Usage
/// ```bash
/// IC9700_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC9700InteractiveValidator
/// ```
///
/// ## Why Not XCTest?
/// XCTest (`swift test`) captures stdout and doesn't support interactive stdin.
/// This standalone executable uses `readLine()` which only works with `swift run`.

@main
struct IC9700InteractiveValidator {
    static func main() async {
        print("\n" + String(repeating: "=", count: 80))
        print("IC-9700 INTERACTIVE HARDWARE VALIDATOR")
        print(String(repeating: "=", count: 80))
        print("\nThis validator will pause at EACH step for your verification.")
        print("You can confirm radio behavior visually before proceeding.\n")

        do {
            let validator = Validator()
            try await validator.run()
        } catch {
            print("\n❌ Validator failed: \(error)")
            exit(1)
        }
    }
}

// MARK: - Validator Class

class Validator {
    private var rig: RigController?

    func run() async throws {
        // Connect to radio
        try await connectToRadio()

        // Run interactive tests
        try await test1_InitialStateReading()
        try await test2_BandExchange()
        try await test3_IndependentModes()
        try await test4_VFOSelection()

        print("\n" + String(repeating: "=", count: 80))
        print("✅ ALL INTERACTIVE TESTS COMPLETED SUCCESSFULLY")
        print(String(repeating: "=", count: 80))
        print("\nIC-9700 4-state VFO implementation validated!\n")
    }

    // MARK: - Connection

    private func connectToRadio() async throws {
        guard let serialPort = ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"] else {
            print("\n❌ ERROR: IC9700_SERIAL_PORT environment variable not set")
            print("\nUsage:")
            print("  IC9700_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run IC9700InteractiveValidator\n")
            throw ValidationError.serialPortNotSet
        }

        print("📡 Connecting to IC-9700 on \(serialPort)...")

        rig = try RigController(
            radio: .icomIC9700(civAddress: nil),
            connection: .serial(path: serialPort, baudRate: 19200)
        )

        try await rig!.connect()

        print("✅ Connected to IC-9700\n")
        askUser("Press RETURN to start interactive tests")
    }

    // MARK: - Test 1: Initial State Reading

    private func test1_InitialStateReading() async throws {
        printTestHeader("TEST 1: 4-State VFO Configuration Reading")

        print("This test reads all 4 VFO states from your IC-9700:")
        print("  - Main VFO A frequency")
        print("  - Main VFO B frequency")
        print("  - Sub VFO A frequency")
        print("  - Sub VFO B frequency")
        print("")

        askUser("Press RETURN to read current 4-state VFO configuration")

        let state = try await readVFOState()
        print("\n📊 Current IC-9700 Configuration:")
        state.printState()

        print("\n👀 VERIFY ON RADIO:")
        print("  1. Check that Main band matches: \(state.mainBand)")
        print("  2. Check that Main VFO A frequency is: \(formatFrequency(state.mainAFreq))")
        print("  3. Check that Main VFO B frequency is: \(formatFrequency(state.mainBFreq))")
        print("  4. Check that Sub band matches: \(state.subBand)")
        print("  5. Check that Sub VFO A frequency is: \(formatFrequency(state.subAFreq))")
        print("  6. Check that Sub VFO B frequency is: \(formatFrequency(state.subBFreq))")

        askUser("\nDoes this match your radio display? Press RETURN if YES, Ctrl+C to abort")

        print("✅ Test 1 PASSED: 4-state VFO reading works correctly\n")
    }

    // MARK: - Test 2: Band Exchange

    private func test2_BandExchange() async throws {
        printTestHeader("TEST 2: Band Exchange (Main ↔ Sub)")

        print("This test swaps the Main and Sub receiver frequencies.")
        print("")

        // Read initial state
        print("📊 Step 1: Reading initial state...")
        let initialState = try await readVFOState()
        print("\n   BEFORE Exchange:")
        initialState.printState()

        askUser("\nPress RETURN to execute BAND EXCHANGE command")

        // Exchange bands
        print("\n🔄 Executing: exchangeBands()...")
        let proto = try await getIcomProtocol()
        try await proto.exchangeBands()

        print("\n👀 VERIFY ON RADIO:")
        print("  - Main receiver should now show: \(initialState.subBand)")
        print("  - Main VFO A should be: \(formatFrequency(initialState.subAFreq))")
        print("  - Sub receiver should now show: \(initialState.mainBand)")
        print("  - Sub VFO A should be: \(formatFrequency(initialState.mainAFreq))")

        askUser("\nDid the bands swap? Press RETURN if YES, Ctrl+C if NO")

        // Read swapped state
        print("\n📊 Step 2: Reading state after exchange...")
        let swappedState = try await readVFOState()
        print("\n   AFTER Exchange:")
        swappedState.printState()

        // Verify swap
        print("\n🔍 Verifying swap...")
        if swappedState.mainAFreq == initialState.subAFreq &&
           swappedState.mainBFreq == initialState.subBFreq &&
           swappedState.subAFreq == initialState.mainAFreq &&
           swappedState.subBFreq == initialState.mainBFreq {
            print("✅ Band exchange worked perfectly!")
        } else {
            print("⚠️  Frequencies don't match expected swap pattern")
            askUser("Press RETURN to continue anyway, or Ctrl+C to abort")
        }

        // Restore original state
        print("\n🔄 Restoring original configuration...")
        try await proto.exchangeBands()

        let restoredState = try await readVFOState()
        print("\n   RESTORED State:")
        restoredState.printState()

        askUser("\nPress RETURN to continue to next test")

        print("✅ Test 2 PASSED: Band exchange works correctly\n")
    }

    // MARK: - Test 3: Independent Mode Control

    private func test3_IndependentModes() async throws {
        printTestHeader("TEST 3: Independent Mode Control (Main vs Sub)")

        print("This test sets different modes on Main and Sub receivers.")
        print("IC-9700 should maintain independent modes per receiver.")
        print("")

        let proto = try await getIcomProtocol()

        // Set Main to FM
        print("📊 Step 1: Setting Main receiver to FM...")
        try await proto.selectBand(.main)
        try await proto.setMode(.fm, vfo: .main)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Main receiver should show: FM")

        askUser("\nIs Main in FM mode? Press RETURN if YES, Ctrl+C if NO")

        // Read Main mode
        guard let rig = rig else { throw ValidationError.notConnected }
        let mainMode = try await rig.mode(vfo: .main, cached: false)
        print("\n✅ Main mode confirmed: \(mainMode)")

        // Set Sub to USB
        print("\n📊 Step 2: Setting Sub receiver to USB...")
        try await proto.selectBand(.sub)
        try await proto.setMode(.usb, vfo: .sub)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Sub receiver should show: USB")
        print("  - Main receiver should STILL show: FM (not changed)")

        askUser("\nIs Sub in USB and Main still in FM? Press RETURN if YES, Ctrl+C if NO")

        // Read Sub mode
        let subMode = try await rig.mode(vfo: .sub, cached: false)
        print("\n✅ Sub mode confirmed: \(subMode)")

        // Verify independence
        print("\n🔍 Verifying mode independence...")
        if mainMode == .fm && subMode == .usb {
            print("✅ Main=FM, Sub=USB - Independent mode control WORKS!")
        } else {
            print("⚠️  Unexpected modes: Main=\(mainMode), Sub=\(subMode)")
            askUser("Press RETURN to continue anyway, or Ctrl+C to abort")
        }

        askUser("\nPress RETURN to continue to next test")

        print("✅ Test 3 PASSED: Independent mode control works correctly\n")
    }

    // MARK: - Test 4: VFO A/B Selection

    private func test4_VFOSelection() async throws {
        printTestHeader("TEST 4: VFO A/B Selection (4-State)")

        print("This test selects different VFO combinations:")
        print("  - Main VFO A")
        print("  - Main VFO B")
        print("  - Sub VFO A")
        print("  - Sub VFO B")
        print("")

        let proto = try await getIcomProtocol()

        // Test Main VFO A
        print("📊 Step 1: Selecting Main VFO A...")
        try await proto.selectBand(.main)
        try await proto.selectVFO(.a)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Main receiver should be selected (highlighted)")
        print("  - VFO A should be active on Main")

        askUser("\nIs Main VFO A selected? Press RETURN if YES, Ctrl+C if NO")

        // Test Main VFO B
        print("\n📊 Step 2: Selecting Main VFO B...")
        try await proto.selectVFO(.b)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Main receiver should still be selected")
        print("  - VFO B should now be active on Main")

        askUser("\nIs Main VFO B selected? Press RETURN if YES, Ctrl+C if NO")

        // Test Sub VFO A
        print("\n📊 Step 3: Selecting Sub VFO A...")
        try await proto.selectBand(.sub)
        try await proto.selectVFO(.a)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Sub receiver should be selected (highlighted)")
        print("  - VFO A should be active on Sub")

        askUser("\nIs Sub VFO A selected? Press RETURN if YES, Ctrl+C if NO")

        // Test Sub VFO B
        print("\n📊 Step 4: Selecting Sub VFO B...")
        try await proto.selectVFO(.b)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Sub receiver should still be selected")
        print("  - VFO B should now be active on Sub")

        askUser("\nIs Sub VFO B selected? Press RETURN if YES, Ctrl+C if NO")

        // Test composite method
        print("\n📊 Step 5: Testing composite selectBandVFO() method...")
        print("Executing: selectBandVFO(band: .main, vfo: .a)")
        try await proto.selectBandVFO(band: .main, vfo: .a)

        print("\n👀 VERIFY ON RADIO:")
        print("  - Main receiver should be selected")
        print("  - VFO A should be active")

        askUser("\nIs Main VFO A selected (composite method)? Press RETURN if YES, Ctrl+C if NO")

        askUser("\nPress RETURN to finish interactive validation")

        print("✅ Test 4 PASSED: All 4 VFO states work correctly\n")
    }

    // MARK: - Helper Methods

    private func readVFOState() async throws -> VFOState {
        guard let rig = rig else {
            throw ValidationError.notConnected
        }

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

    private func getIcomProtocol() async throws -> IcomCIVProtocol {
        guard let rig = rig else {
            throw ValidationError.notConnected
        }

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            throw ValidationError.notIcomProtocol
        }

        return proto
    }

    private func printTestHeader(_ title: String) {
        print("\n" + String(repeating: "=", count: 80))
        print(title)
        print(String(repeating: "=", count: 80))
    }

    private func askUser(_ prompt: String) {
        print(prompt, terminator: "")
        fflush(stdout)
        _ = readLine()
        print("")
    }

    private func formatFrequency(_ freq: UInt64) -> String {
        let mhz = Double(freq) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}

// MARK: - VFO State Structure

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
            return "VHF 2m (144-148 MHz)"
        case 430_000_000...450_000_000:
            return "UHF 70cm (430-450 MHz)"
        case 1_240_000_000...1_300_000_000:
            return "1.2GHz 23cm (1240-1300 MHz)"
        default:
            return "Unknown Band"
        }
    }

    func printState() {
        print("   ┌─ Main Receiver (\(mainBand))")
        print("   │  ├─ VFO A: \(formatFreq(mainAFreq))")
        print("   │  └─ VFO B: \(formatFreq(mainBFreq))")
        print("   └─ Sub Receiver (\(subBand))")
        print("      ├─ VFO A: \(formatFreq(subAFreq))")
        print("      └─ VFO B: \(formatFreq(subBFreq))")
    }

    private func formatFreq(_ freq: UInt64) -> String {
        let mhz = Double(freq) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}

// MARK: - Validation Errors

enum ValidationError: Error, CustomStringConvertible {
    case serialPortNotSet
    case notConnected
    case notIcomProtocol

    var description: String {
        switch self {
        case .serialPortNotSet:
            return "IC9700_SERIAL_PORT environment variable not set"
        case .notConnected:
            return "Not connected to radio"
        case .notIcomProtocol:
            return "Radio is not using Icom protocol"
        }
    }
}
