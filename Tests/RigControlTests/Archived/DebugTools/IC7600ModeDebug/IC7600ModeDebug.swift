import Foundation
import RigControl

@main
struct IC7600ModeDebug {
    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║     IC-7600 Mode Setting Debug                            ║")
        print("║     Traces exact CI-V frames for mode commands            ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        let port = "/dev/cu.usbserial-2120"
        let baudRate = 19200

        print("Connecting to IC-7600 on \(port) @ \(baudRate) baud...")

        let rig = RigController(
            radio: .icomIC7600,
            connection: .serial(path: port, baudRate: baudRate)
        )

        do {
            try await rig.connect()
            print("✓ Connected\n")

            // Read current state
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("READING CURRENT STATE")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            let currentFreq = try await rig.frequency(vfo: VFO.main, cached: false)
            let currentMode = try await rig.mode(vfo: VFO.main, cached: false)

            print("Current Main Frequency: \(Double(currentFreq) / 1_000_000) MHz")
            print("Current Main Mode: \(currentMode)")
            print()

            // Test 1: Set frequency to 14.200 MHz (20m - USB appropriate)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("TEST 1: SET FREQUENCY TO 14.200 MHz")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            try await rig.setFrequency(14_200_000, vfo: VFO.main)
            let newFreq = try await rig.frequency(vfo: VFO.main, cached: false)
            print("✓ Frequency set to: \(Double(newFreq) / 1_000_000) MHz")
            print()

            // Test 2: Attempt to set mode to USB
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("TEST 2: SET MODE TO USB")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Command will be: 0x06 (setMode), 0x01 (USB), 0x00 (filter)")
            print()

            do {
                print("Sending setMode(USB) command...")
                try await rig.setMode(Mode.usb, vfo: VFO.main)
                print("✓ Command accepted by radio!")

                let verifyMode = try await rig.mode(vfo: VFO.main, cached: false)
                print("✓ Verified mode: \(verifyMode)")

            } catch {
                print("❌ ERROR: \(error)")
                print()
                print("Checking if mode actually changed on radio...")
                let actualMode = try await rig.mode(vfo: VFO.main, cached: false)
                print("Radio reports mode as: \(actualMode)")
            }
            print()

            // Test 3: Try setting mode to LSB on lower HF
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("TEST 3: SET FREQUENCY TO 3.750 MHz, THEN MODE TO LSB")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            try await rig.setFrequency(3_750_000, vfo: VFO.main)
            print("✓ Frequency set to 3.750 MHz")
            print("Command will be: 0x06 (setMode), 0x00 (LSB), 0x00 (filter)")
            print()

            do {
                print("Sending setMode(LSB) command...")
                try await rig.setMode(Mode.lsb, vfo: VFO.main)
                print("✓ Command accepted by radio!")

                let verifyMode = try await rig.mode(vfo: VFO.main, cached: false)
                print("✓ Verified mode: \(verifyMode)")

            } catch {
                print("❌ ERROR: \(error)")
                print()
                print("Checking if mode actually changed on radio...")
                let actualMode = try await rig.mode(vfo: VFO.main, cached: false)
                print("Radio reports mode as: \(actualMode)")
            }
            print()

            // Test 4: Try reading mode without setting (to see response format)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("TEST 4: MULTIPLE MODE READS")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            for i in 1...3 {
                let mode = try await rig.mode(vfo: VFO.main, cached: false)
                print("Read \(i): \(mode)")
                try await Task.sleep(for: .milliseconds(200))
            }
            print()

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("✓ ALL TESTS COMPLETE")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await rig.disconnect()

        } catch {
            print("❌ FATAL ERROR: \(error)")
            await rig.disconnect()
            Foundation.exit(1)
        }
    }
}
