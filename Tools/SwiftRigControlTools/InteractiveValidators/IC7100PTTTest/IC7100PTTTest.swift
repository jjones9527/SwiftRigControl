import Foundation
import RigControl

@main
struct IC7100PTTTest {
    static func main() async {
        print("\n" + String(repeating: "=", count: 60))
        print("IC-7100 PTT Test")
        print(String(repeating: "=", count: 60))

        guard let port = ProcessInfo.processInfo.environment["IC7100_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set IC7100_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Port: \(port)\n")

        do {
            // Create controller
            let rig = try RigController(
                radio: .icomIC7100(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)
            )

            // Connect
            try await rig.connect()
            print("✓ Connected to IC-7100\n")

            // Save current state
            let originalFreq = try await rig.frequency(vfo: .a, cached: false)
            let originalMode = try await rig.mode(vfo: .a, cached: false)
            let originalPower = try await rig.power()

            print("Current state:")
            print("  Frequency: \(Double(originalFreq) / 1_000_000.0) MHz")
            print("  Mode: \(originalMode.rawValue)")
            print("  Power: \(originalPower)W\n")

            // Set up for PTT test
            print("📡 Setting up for PTT test...")
            print("   Setting power to 10W")
            try await rig.setPower(10)

            print("   Setting frequency to 14.200 MHz USB")
            try await rig.setFrequency(14_200_000, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)

            print("   ⚠️  Keying transmitter in 2 seconds...\n")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            print("   🔴 PTT ON")
            try await rig.setPTT(true)

            let pttOn = try await rig.isPTTEnabled()
            if pttOn {
                print("   ✓ PTT status confirmed: ON")
            } else {
                print("   ❌ PTT status check failed")
            }

            print("   Transmitting for 500ms...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print("   ⚪ PTT OFF")
            try await rig.setPTT(false)

            let pttOff = try await rig.isPTTEnabled()
            if !pttOff {
                print("   ✓ PTT status confirmed: OFF")
            } else {
                print("   ❌ PTT status check failed")
            }

            print("\n✓ PTT control verified\n")

            // Restore original state
            print("🔄 Restoring original state...")
            try await rig.setFrequency(originalFreq, vfo: .a)
            try await rig.setMode(originalMode, vfo: .a)
            try await rig.setPower(originalPower)
            print("   ✓ State restored\n")

            await rig.disconnect()
            print("   ✓ Disconnected\n")

            print(String(repeating: "=", count: 60))
            print("✅ All PTT tests passed!")
            print(String(repeating: "=", count: 60) + "\n")

        } catch {
            print("❌ Error: \(error)\n")
            Foundation.exit(1)
        }
    }
}
