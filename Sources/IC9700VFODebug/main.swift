import Foundation
import RigControl

/// Debug program to examine IC-9700 basic communication
@main
struct IC9700VFODebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-9700 Basic Communication Test")
        print(String(repeating: "=", count: 70) + "\n")

        guard let port = ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set IC9700_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Port: \(port)\n")

        do {
            // Create controller
            let rig = try RigController(
                radio: .icomIC9700(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)  // Use default 19200
            )

            try await rig.connect()
            print("✓ Connected\n")

            print("Test 1: Reading frequency from current band...")
            let freq = try await rig.frequency(vfo: .a, cached: false)
            print("   ✓ Frequency: \(formatFreq(freq))\n")

            print("Test 2: Reading mode from current band...")
            let mode = try await rig.mode(vfo: .a, cached: false)
            print("   ✓ Mode: \(mode.rawValue)\n")

            print("Test 3: Setting frequency...")
            try await rig.setFrequency(435_000_000, vfo: .a)
            let newFreq = try await rig.frequency(vfo: .a, cached: false)
            print("   ✓ New frequency: \(formatFreq(newFreq))\n")

            await rig.disconnect()
            print("✓ Disconnected\n")

            print(String(repeating: "=", count: 70))
            print("Basic communication successful!")
            print(String(repeating: "=", count: 70) + "\n")

        } catch {
            print("❌ Error: \(error)\n")
            Foundation.exit(1)
        }
    }

    static func formatFreq(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
