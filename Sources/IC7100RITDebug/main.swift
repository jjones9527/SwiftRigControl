import Foundation
import RigControl

/// Debug program to examine IC-7100 RIT response format
@main
struct IC7100RITDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-7100 RIT Response Debug")
        print("Examining raw CI-V responses for RIT commands")
        print(String(repeating: "=", count: 70) + "\n")

        guard let port = ProcessInfo.processInfo.environment["IC7100_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set IC7100_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Configuration:")
        print("  Port: \(port)")
        print("  Radio: IC-7100 (CI-V Address: 0x88)")
        print("")

        do {
            // Create controller
            let rig = try RigController(
                radio: .icomIC7100(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)
            )

            try await rig.connect()
            print("✓ Connected to IC-7100\n")

            // Get the protocol to access low-level frame sending
            let proto = await rig.protocol
            guard let icomProtocol = proto as? IcomCIVProtocol else {
                print("❌ Could not access Icom protocol")
                Foundation.exit(1)
            }

            // Test 1: Set RIT to +500 Hz
            print("📤 Test 1: Setting RIT to +500 Hz")
            print("   Command: 21 00 00 05 00 (RIT frequency +500 Hz)")

            try await rig.setRIT(RITXITState(enabled: true, offset: 500))
            print("   ✓ Command sent successfully")
            print("   ⚠️  Check radio display - RIT should show +0.50 kHz\n")

            // Test 2: Read RIT state back
            print("📥 Test 2: Reading RIT state back")
            let ritState = try await rig.getRIT(cached: false)
            print("   ✓ RIT enabled: \(ritState.enabled)")
            print("   ✓ RIT offset: \(ritState.offset) Hz\n")

            // Test 3: Try negative offset
            print("📤 Test 3: Setting RIT to -300 Hz")
            try await rig.setRIT(RITXITState(enabled: true, offset: -300))
            let ritState2 = try await rig.getRIT(cached: false)
            print("   ✓ RIT enabled: \(ritState2.enabled)")
            print("   ✓ RIT offset: \(ritState2.offset) Hz")
                print("   Raw BCD data: \(dataStr)")

                // Manual decode attempt
                if offsetResponse.data.count == 3 {
                    let direction = offsetResponse.data[0]
                    let byte1 = offsetResponse.data[1]
                    let byte2 = offsetResponse.data[2]
                    print("   Direction byte: 0x\(String(format: "%02X", direction)) (\(direction == 0x00 ? "+" : "-"))")
                    print("   Frequency byte 1: 0x\(String(format: "%02X", byte1))")
                    print("   Frequency byte 2: 0x\(String(format: "%02X", byte2))")
                }
            }
            print("")

            // Test 4: Disable RIT
            print("📤 Test 4: Disabling RIT")
            try await rig.setRIT(RITXITState(enabled: false, offset: 0))
            print("   ✓ RIT disabled\n")

            await rig.disconnect()
            print("✓ Disconnected\n")

            print(String(repeating: "=", count: 70))
            print("Debug session complete")
            print(String(repeating: "=", count: 70) + "\n")

        } catch {
            print("❌ Error: \(error)\n")
            Foundation.exit(1)
        }
    }
}
