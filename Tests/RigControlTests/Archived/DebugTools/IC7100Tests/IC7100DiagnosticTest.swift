import Foundation
import RigControl

/// Detailed diagnostic test for IC-7100 connection issues
@main
struct IC7100DiagnosticTest {
    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║        IC-7100 Diagnostic Test                             ║")
        print("║        Detailed Connection Analysis                        ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        let ports = [
            "/dev/cu.usbserial-2110",
            "/dev/cu.usbserial-2130"
        ]

        print("Radio Settings (as reported by user):")
        print("  • CI-V USB Port: ON")
        print("  • CI-V Baud Rate: 19200")
        print("  • CI-V Address: 88h (136 decimal)")
        print("  • Connection: Rear USB port")
        print()

        for port in ports {
            await testPortDetailed(port: port)
            print()
        }

        // Try different baud rates on both ports
        print("╔════════════════════════════════════════════════════════════╗")
        print("║  Testing Alternative Baud Rates                           ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        let baudRates = [4800, 9600, 19200, 38400, 115200]

        for port in ports {
            for baud in baudRates {
                await testPortWithBaud(port: port, baudRate: baud)
            }
            print()
        }
    }

    static func testPortDetailed(port: String) async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing: \(port)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: port, baudRate: 19200)
        )

        print("Step 1: Attempting connection...")

        do {
            try await rig.connect()
            print("  ✓ Serial port opened successfully")

            print("Step 2: Reading frequency...")
            do {
                let freq = try await rig.frequency(vfo: .a)
                print("  ✓ SUCCESS! Got response from radio")
                print("  ✓ Frequency: \(formatFrequency(freq))")
                print()
                print("  🎉 THIS IS THE CORRECT PORT: \(port)")

                // Try to get mode too
                let mode = try await rig.mode(vfo: .a)
                print("  ✓ Mode: \(mode)")

                await rig.disconnect()
                return

            } catch RigError.timeout {
                print("  ✗ TIMEOUT: Radio did not respond to commands")
                print("    → Port opened, but no CI-V response received")
                print("    → This might be the audio port (not control port)")
            } catch {
                print("  ✗ ERROR: \(error)")
            }

            await rig.disconnect()

        } catch RigError.serialPortError(let message) {
            print("  ✗ Failed to open serial port")
            print("    Error: \(message)")
        } catch {
            print("  ✗ Unexpected error: \(error)")
        }
    }

    static func testPortWithBaud(port: String, baudRate: Int) async {
        let portShort = port.components(separatedBy: "/").last ?? port

        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: port, baudRate: baudRate)
        )

        do {
            try await rig.connect()
            let freq = try await rig.frequency(vfo: .a)
            print("  ✓ SUCCESS: \(portShort) @ \(baudRate) baud → \(formatFrequency(freq))")
            await rig.disconnect()
        } catch {
            print("  ✗ FAIL: \(portShort) @ \(baudRate) baud")
            await rig.disconnect()
        }
    }

    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
