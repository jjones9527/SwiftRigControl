import Foundation
import RigControl

/// Interactive test - pauses after each step for user verification
@main
struct IC7100InteractiveTest {
    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║     IC-7100 Interactive Step-by-Step Test                 ║")
        print("║     Please report what you see on the radio display       ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        )

        do {
            try await rig.connect()
            print("✓ Connected to IC-7100\n")

            // ═══════════════════════════════════════════════════════════
            print("═══════════════════════════════════════════════════════════")
            print("STEP 1: READ CURRENT STATE")
            print("═══════════════════════════════════════════════════════════")
            let freq1 = try await rig.frequency(vfo: .a)
            let mode1 = try await rig.mode(vfo: .a)

            print()
            print("Software says:")
            print("  Frequency: \(formatFrequency(freq1))")
            print("  Mode: \(mode1)")
            print()
            print("👉 QUESTION: What does your radio display show?")
            print("   Frequency: ________________")
            print("   Mode: ________________")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 2: SET FREQUENCY TO 14.250 MHz")
            print("═══════════════════════════════════════════════════════════")
            print("Sending command to set frequency to 14.250 MHz...")
            try await rig.setFrequency(14_250_000, vfo: .a)
            try await Task.sleep(nanoseconds: 300_000_000)

            let freq2 = try await rig.frequency(vfo: .a)
            print()
            print("Software says frequency is now: \(formatFrequency(freq2))")
            if freq2 == 14_250_000 {
                print("✓ Read back matches what we set")
            } else {
                print("⚠️  Read back does NOT match (expected 14.250)")
            }
            print()
            print("👉 QUESTION: What frequency does your radio display show?")
            print("   Display shows: ________________ MHz")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 3: SET FREQUENCY TO 7.074 MHz (40m)")
            print("═══════════════════════════════════════════════════════════")
            print("Sending command to set frequency to 7.074 MHz...")
            try await rig.setFrequency(7_074_000, vfo: .a)
            try await Task.sleep(nanoseconds: 300_000_000)

            let freq3 = try await rig.frequency(vfo: .a)
            print()
            print("Software says frequency is now: \(formatFrequency(freq3))")
            if freq3 == 7_074_000 {
                print("✓ Read back matches what we set")
            } else {
                print("⚠️  Read back does NOT match (expected 7.074)")
            }
            print()
            print("👉 QUESTION: What frequency does your radio display show?")
            print("   Display shows: ________________ MHz")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 4: READ CURRENT MODE")
            print("═══════════════════════════════════════════════════════════")
            let currentMode = try await rig.mode(vfo: .a)
            print()
            print("Software says current mode is: \(currentMode)")
            print()
            print("👉 QUESTION: What mode does your radio display show?")
            print("   Display shows: ________________")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 5: SET MODE TO USB")
            print("═══════════════════════════════════════════════════════════")
            print("Sending command to set mode to USB...")
            do {
                try await rig.setMode(.usb, vfo: .a)
                try await Task.sleep(nanoseconds: 300_000_000)
                let mode5 = try await rig.mode(vfo: .a)
                print()
                print("✓ Command succeeded!")
                print("Software says mode is now: \(mode5)")
            } catch {
                print()
                print("❌ Command FAILED: \(error)")
                print("(Radio rejected the command)")
            }
            print()
            print("👉 QUESTION: What mode does your radio display show?")
            print("   Display shows: ________________")
            print("   Did the mode change? YES / NO")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 6: SET MODE TO LSB")
            print("═══════════════════════════════════════════════════════════")
            print("Sending command to set mode to LSB...")
            do {
                try await rig.setMode(.lsb, vfo: .a)
                try await Task.sleep(nanoseconds: 300_000_000)
                let mode6 = try await rig.mode(vfo: .a)
                print()
                print("✓ Command succeeded!")
                print("Software says mode is now: \(mode6)")
            } catch {
                print()
                print("❌ Command FAILED: \(error)")
            }
            print()
            print("👉 QUESTION: What mode does your radio display show?")
            print("   Display shows: ________________")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 7: SET MODE TO FM")
            print("═══════════════════════════════════════════════════════════")
            print("Sending command to set mode to FM...")
            do {
                try await rig.setMode(.fm, vfo: .a)
                try await Task.sleep(nanoseconds: 300_000_000)
                let mode7 = try await rig.mode(vfo: .a)
                print()
                print("✓ Command succeeded!")
                print("Software says mode is now: \(mode7)")
            } catch {
                print()
                print("❌ Command FAILED: \(error)")
            }
            print()
            print("👉 QUESTION: What mode does your radio display show?")
            print("   Display shows: ________________")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 8: READ POWER LEVEL")
            print("═══════════════════════════════════════════════════════════")
            do {
                let power = try await rig.power()
                print()
                print("Software says power is: \(power)W")
                print("(Note: IC-7100 max is 100W)")
            } catch {
                print()
                print("❌ Read power FAILED: \(error)")
            }
            print()
            print("👉 QUESTION: What power level does your radio display show?")
            print("   Display shows: ________________ W")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 9: SET POWER TO 50W")
            print("═══════════════════════════════════════════════════════════")
            print("Sending command to set power to 50W...")
            do {
                try await rig.setPower(50)
                try await Task.sleep(nanoseconds: 300_000_000)
                let power9 = try await rig.power()
                print()
                print("✓ Command succeeded!")
                print("Software says power is now: \(power9)W")
            } catch {
                print()
                print("❌ Command FAILED: \(error)")
            }
            print()
            print("👉 QUESTION: What power level does your radio display show?")
            print("   Display shows: ________________ W")
            print("   Did the power change? YES / NO")
            waitForUser()

            // ═══════════════════════════════════════════════════════════
            print("\n═══════════════════════════════════════════════════════════")
            print("STEP 10: READ PTT STATE")
            print("═══════════════════════════════════════════════════════════")
            do {
                let ptt = try await rig.isPTTEnabled()
                print()
                print("Software says PTT is: \(ptt ? "ON (transmitting)" : "OFF (receiving)")")
            } catch {
                print()
                print("❌ Read PTT FAILED: \(error)")
            }
            print()
            print("👉 QUESTION: Is your radio transmitting or receiving?")
            print("   TX light: ON / OFF")
            waitForUser()

            print("\n═══════════════════════════════════════════════════════════")
            print("✓ ALL TESTS COMPLETE")
            print("═══════════════════════════════════════════════════════════\n")

            await rig.disconnect()
            print("Disconnected from radio.\n")

        } catch {
            print("\n❌ FATAL ERROR: \(error)\n")
        }
    }

    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f", mhz)
    }

    static func waitForUser() {
        print()
        print("Press RETURN when ready to continue...")
        _ = readLine()
    }
}
