import Foundation
import RigControl

/// Debug test to investigate IC-7100 command issues
@main
struct IC7100DebugTest {
    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║        IC-7100 Debug Test                                  ║")
        print("║        Investigating Command Issues                        ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        )

        do {
            try await rig.connect()
            print("✓ Connected\n")

            // Test 1: Read current frequency
            print("━━━ TEST 1: READ FREQUENCY ━━━")
            let freq1 = try await rig.frequency(vfo: .a)
            print("Current frequency: \(formatFrequency(freq1))")
            print()

            // Test 2: Write frequency and verify
            print("━━━ TEST 2: WRITE FREQUENCY (14.230 MHz) ━━━")
            print("Before: Radio should show \(formatFrequency(freq1))")
            try await rig.setFrequency(14_230_000, vfo: .a)

            // Wait a moment for radio to update
            try await Task.sleep(nanoseconds: 500_000_000)

            let freq2 = try await rig.frequency(vfo: .a)
            print("After write, read back: \(formatFrequency(freq2))")

            if freq2 == 14_230_000 {
                print("✓ Frequency write SUCCESSFUL")
            } else {
                print("❌ Frequency write FAILED - Expected 14.230 MHz, got \(formatFrequency(freq2))")
            }
            print()
            print("QUESTION: What does your radio display show right now?")
            print()

            // Test 3: Try different frequency
            print("━━━ TEST 3: WRITE DIFFERENT FREQUENCY (7.074 MHz) ━━━")
            try await rig.setFrequency(7_074_000, vfo: .a)
            try await Task.sleep(nanoseconds: 500_000_000)
            let freq3 = try await rig.frequency(vfo: .a)
            print("Set 7.074 MHz, read back: \(formatFrequency(freq3))")
            print("QUESTION: What does your radio display show now?")
            print()

            // Test 4: Read current mode
            print("━━━ TEST 4: READ MODE ━━━")
            let mode1 = try await rig.mode(vfo: .a)
            print("Current mode: \(mode1)")
            print()

            // Test 5: Try setting USB mode
            print("━━━ TEST 5: SET MODE TO USB ━━━")
            do {
                try await rig.setMode(.usb, vfo: .a)
                try await Task.sleep(nanoseconds: 500_000_000)
                let mode2 = try await rig.mode(vfo: .a)
                print("✓ Mode set successfully, read back: \(mode2)")
                print("QUESTION: Is radio in USB mode?")
            } catch {
                print("❌ Set USB mode failed: \(error)")
            }
            print()

            // Test 6: Try setting FM mode
            print("━━━ TEST 6: SET MODE TO FM ━━━")
            do {
                try await rig.setMode(.fm, vfo: .a)
                try await Task.sleep(nanoseconds: 500_000_000)
                let mode3 = try await rig.mode(vfo: .a)
                print("✓ Mode set successfully, read back: \(mode3)")
                print("QUESTION: Is radio in FM mode?")
            } catch {
                print("❌ Set FM mode failed: \(error)")
            }
            print()

            // Test 7: Power read
            print("━━━ TEST 7: READ POWER ━━━")
            do {
                let power = try await rig.power()
                print("Read power: \(power)W")
                print("QUESTION: What power level is shown on radio?")
            } catch {
                print("❌ Read power failed: \(error)")
            }
            print()

            // Test 8: Power write
            print("━━━ TEST 8: SET POWER TO 50W ━━━")
            do {
                try await rig.setPower(50)
                try await Task.sleep(nanoseconds: 500_000_000)
                let power2 = try await rig.power()
                print("✓ Power set, read back: \(power2)W")
                print("QUESTION: Does radio show 50W?")
            } catch {
                print("❌ Set power failed: \(error)")
            }
            print()

            await rig.disconnect()
            print("✓ Disconnected")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }

    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
