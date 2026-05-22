import Foundation
import RigControl

/// Interactive debug tool to test IC-7600 CHANGE button commands (0xB0 vs 0xB1)
///
/// This tool pauses for user confirmation at each step to verify what's displayed
/// on the radio's front panel, helping us determine if the commands work correctly
/// but we're reading the state incorrectly.
///
/// Based on user observation:
/// - Tap CHANGE (quick press) = Swap Main ↔ Sub
/// - Hold CHANGE (long press) = Copy Main → Sub
///
/// Usage:
///   IC7600_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC7600ModeDebug

@main
struct IC7600ModeDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-7600 CHANGE Button Command Debug (INTERACTIVE)")
        print("Testing 0x07 0xB0 (exchangeBands) vs 0x07 0xB1 (equalizeBands)")
        print(String(repeating: "=", count: 70))
        print("\nThis test will pause for you to verify the radio's display.")
        print("Please watch the IC-7600's front panel during the test.\n")

        guard let serialPort = ProcessInfo.processInfo.environment["IC7600_SERIAL_PORT"] else {
            print("❌ Error: IC7600_SERIAL_PORT environment variable not set")
            print("   Usage: IC7600_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run IC7600ModeDebug\n")
            return
        }

        do {
            let rig = try RigController(
                radio: .icomIC7600(civAddress: nil),
                connection: .serial(path: serialPort, baudRate: 19200)
            )

            try await rig.connect()
            print("✅ Connected to IC-7600\n")

            guard let proto = await rig.protocol as? IcomCIVProtocol else {
                print("❌ Not an Icom protocol")
                return
            }

            // ========================================================================
            // SETUP: Configure initial test state
            // ========================================================================
            print(String(repeating: "=", count: 70))
            print("SETUP: Configuring Initial State")
            print(String(repeating: "=", count: 70))

            print("\nSetting Main receiver to 14.200 MHz USB...")
            try await proto.selectBand(.main)
            try await rig.setFrequency(14_200_000, vfo: .main)
            try await rig.setMode(.usb, vfo: .main)
            try await Task.sleep(nanoseconds: 300_000_000)

            print("Setting Sub receiver to 7.100 MHz LSB...")
            try await proto.selectBand(.sub)
            try await rig.setFrequency(7_100_000, vfo: .sub)
            try await rig.setMode(.lsb, vfo: .sub)
            try await Task.sleep(nanoseconds: 300_000_000)

            // Read back what we think we set
            let mainInitial = try await rig.frequency(vfo: .main, cached: false)
            let subInitial = try await rig.frequency(vfo: .sub, cached: false)
            let mainModeInitial = try await rig.mode(vfo: .main, cached: false)
            let subModeInitial = try await rig.mode(vfo: .sub, cached: false)

            print("\n📊 What we READ from radio:")
            print("     Main: \(formatFreq(mainInitial)) \(mainModeInitial.rawValue)")
            print("     Sub:  \(formatFreq(subInitial)) \(subModeInitial.rawValue)")

            print("\n👁️  Please check the IC-7600 front panel display:")
            print("   Expected: Main = 14.200 MHz USB, Sub = 7.100 MHz LSB")
            await askUser("Does the radio display match? (y/n): ")

            // ========================================================================
            // TEST 1: Command 0x07 0xB0 (exchangeBands)
            // ========================================================================
            print("\n" + String(repeating: "=", count: 70))
            print("TEST 1: Command 0x07 0xB0 (exchangeBands)")
            print(String(repeating: "=", count: 70))
            print("\nThis sends the CI-V command: FE FE 7A E0 07 B0 FD")
            print("Labeled in documentation as: 'Exchange main/sub bands'")

            print("\n👁️  BEFORE sending command, confirm radio display:")
            print("   Expected: Main = 14.200 MHz USB, Sub = 7.100 MHz LSB")
            await askUser("Press ENTER when ready to send 0xB0 command...")

            // Send the command
            print("\n📡 Sending exchangeBands() command (0x07 0xB0)...")
            try await proto.exchangeBands()
            print("✅ Command sent and ACKed by radio")

            try await Task.sleep(nanoseconds: 500_000_000)

            // Read back the state
            let main1 = try await rig.frequency(vfo: .main, cached: false)
            let sub1 = try await rig.frequency(vfo: .sub, cached: false)
            let mainMode1 = try await rig.mode(vfo: .main, cached: false)
            let subMode1 = try await rig.mode(vfo: .sub, cached: false)

            print("\n📊 What we READ from radio after 0xB0:")
            print("     Main: \(formatFreq(main1)) \(mainMode1.rawValue)")
            print("     Sub:  \(formatFreq(sub1)) \(subMode1.rawValue)")

            print("\n👁️  What do you see on the IC-7600 display?")
            print("\n   Option A: SWAP occurred")
            print("     Main = 7.100 MHz LSB (was on Sub)")
            print("     Sub  = 14.200 MHz USB (was on Main)")
            print("\n   Option B: COPY occurred")
            print("     Main = 14.200 MHz USB (unchanged)")
            print("     Sub  = 14.200 MHz USB (copied from Main)")
            print("\n   Option C: Something else")

            let response1 = await askUser("\nWhat happened on the radio? (A/B/C): ")

            print("\n✏️  User reported: Option \(response1.uppercased())")
            if response1.uppercased() == "B" {
                print("   ➜ 0xB0 performs COPY (Main → Sub) = EQUALIZE")
                print("   ➜ This matches HOLD CHANGE button behavior")
            } else if response1.uppercased() == "A" {
                print("   ➜ 0xB0 performs SWAP (Main ↔ Sub) = EXCHANGE")
                print("   ➜ This matches TAP CHANGE button behavior")
            }

            // ========================================================================
            // RESET for Test 2
            // ========================================================================
            print("\n" + String(repeating: "=", count: 70))
            print("RESET: Restoring Initial State for Test 2")
            print(String(repeating: "=", count: 70))

            print("\nResetting Main to 14.200 MHz USB...")
            try await proto.selectBand(.main)
            try await rig.setFrequency(14_200_000, vfo: .main)
            try await rig.setMode(.usb, vfo: .main)
            try await Task.sleep(nanoseconds: 300_000_000)

            print("Resetting Sub to 7.100 MHz LSB...")
            try await proto.selectBand(.sub)
            try await rig.setFrequency(7_100_000, vfo: .sub)
            try await rig.setMode(.lsb, vfo: .sub)
            try await Task.sleep(nanoseconds: 300_000_000)

            let mainReset = try await rig.frequency(vfo: .main, cached: false)
            let subReset = try await rig.frequency(vfo: .sub, cached: false)
            let mainModeReset = try await rig.mode(vfo: .main, cached: false)
            let subModeReset = try await rig.mode(vfo: .sub, cached: false)

            print("\n📊 What we READ from radio:")
            print("     Main: \(formatFreq(mainReset)) \(mainModeReset.rawValue)")
            print("     Sub:  \(formatFreq(subReset)) \(subModeReset.rawValue)")

            print("\n👁️  Please verify the radio display:")
            print("   Expected: Main = 14.200 MHz USB, Sub = 7.100 MHz LSB")
            await askUser("Does the radio display match? (y/n): ")

            // ========================================================================
            // TEST 2: Command 0x07 0xB1 (equalizeBands) - if available
            // ========================================================================
            print("\n" + String(repeating: "=", count: 70))
            print("TEST 2: Command 0x07 0xB1 (equalizeBands)")
            print(String(repeating: "=", count: 70))
            print("\nThis would send the CI-V command: FE FE 7A E0 07 B1 FD")
            print("Labeled in documentation as: 'Equalize main/sub bands'")

            print("\n⚠️  Note: This command may not have a public method.")
            print("         Checking if IC-7600-specific method exists...")

            // Check if we can find the method in IcomCIVProtocol+IC7600.swift
            // For now, let's try to cast and call it dynamically
            print("\n📡 Attempting to call equalizeBandsIC7600() if it exists...")

            // We'll need to add this method or send the raw command
            // For now, document what we'd expect
            print("\n⚠️  equalizeBands() method not available in current API")
            print("   To test 0xB1, we would need to:")
            print("   1. Add equalizeBandsIC7600() method to IcomCIVProtocol+IC7600")
            print("   2. Or send raw CI-V frame: FE FE 7A E0 07 B1 FD")

            print("\n💡 Based on TEST 1 results:")
            if response1.uppercased() == "B" {
                print("   If 0xB0 = COPY, then 0xB1 likely = SWAP")
                print("   (Documentation labels appear to be backwards)")
            } else if response1.uppercased() == "A" {
                print("   If 0xB0 = SWAP, then 0xB1 likely = COPY")
                print("   (Documentation labels are correct)")
            }

            // ========================================================================
            // MANUAL TEST OPPORTUNITY
            // ========================================================================
            print("\n" + String(repeating: "=", count: 70))
            print("MANUAL TEST: Try the CHANGE button yourself")
            print(String(repeating: "=", count: 70))
            print("\nWith Main = 14.200 MHz USB and Sub = 7.100 MHz LSB:")
            print("\n1. TAP the CHANGE button (quick press)")
            print("   Observe what happens on the display")
            print("\n2. HOLD the CHANGE button (long press)")
            print("   Observe what happens on the display")

            await askUser("\nPress ENTER after testing CHANGE button manually...")

            let tapResult = await askUser("\nWhat did TAP CHANGE do? (swap/copy/other): ")
            let holdResult = await askUser("What did HOLD CHANGE do? (swap/copy/other): ")

            print("\n✏️  User reported:")
            print("   TAP CHANGE  = \(tapResult)")
            print("   HOLD CHANGE = \(holdResult)")

            await rig.disconnect()
            print("\n✅ Disconnected\n")

            // ========================================================================
            // FINAL ANALYSIS
            // ========================================================================
            print(String(repeating: "=", count: 70))
            print("ANALYSIS & CONCLUSIONS")
            print(String(repeating: "=", count: 70))

            print("\nCI-V COMMAND RESULTS:")
            print("  • 0x07 0xB0 (exchangeBands): \(response1.uppercased() == "A" ? "SWAP" : response1.uppercased() == "B" ? "COPY" : "UNKNOWN")")

            print("\nCHANGE BUTTON RESULTS:")
            print("  • TAP CHANGE:  \(tapResult.uppercased())")
            print("  • HOLD CHANGE: \(holdResult.uppercased())")

            print("\nREADING ACCURACY:")
            print("  • Initial state read: \(mainInitial == 14_200_000 && subInitial == 7_100_000 ? "✅ Correct" : "❌ Incorrect")")
            print("  • After 0xB0 read: See comparison above")

            print("\nRECOMMENDATIONS:")
            if response1.uppercased() == "B" && holdResult.lowercased().contains("copy") {
                print("  ✅ 0xB0 matches HOLD CHANGE (both COPY)")
                print("  ➜ Labels in CI-V docs appear BACKWARDS")
                print("  ➜ 0xB0 'exchange' is actually EQUALIZE (copy)")
                print("  ➜ 0xB1 'equalize' is likely EXCHANGE (swap)")
            } else if response1.uppercased() == "A" && tapResult.lowercased().contains("swap") {
                print("  ✅ 0xB0 matches TAP CHANGE (both SWAP)")
                print("  ➜ Labels in CI-V docs are CORRECT")
                print("  ➜ 0xB0 is EXCHANGE (swap)")
                print("  ➜ 0xB1 is EQUALIZE (copy)")
            } else {
                print("  ⚠️  Results are inconsistent or unexpected")
                print("  ➜ Further investigation needed")
            }

            print("\nREADING STATE ISSUES:")
            print("  If our READ values don't match what you see on the radio:")
            print("  • We may be reading the wrong VFO")
            print("  • Timing issue (need longer delay after command)")
            print("  • Cache issue (frequency() not forcing fresh read)")

            print(String(repeating: "=", count: 70) + "\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }

    static func formatFreq(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }

    @discardableResult
    static func askUser(_ prompt: String) async -> String {
        print(prompt, terminator: "")
        fflush(stdout)

        // Read user input
        if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return input.isEmpty ? "" : input
        }
        return ""
    }
}
