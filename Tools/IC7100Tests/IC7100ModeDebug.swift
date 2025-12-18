import Foundation
import RigControl

/// Debug mode command issues with IC-7100
@main
struct IC7100ModeDebug {
    static func main() async {
        print("IC-7100 Mode Command Debug")
        print("==========================\n")

        let config = SerialConfiguration(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)

        do {
            try await transport.open()
            try await transport.flush()
            print("✓ Connected\n")

            // Test 1: Current implementation - Mode with filter byte
            print("TEST 1: Set USB with filter byte (current implementation)")
            print("Command: FE FE 88 E0 06 01 00 FD")
            print("  (06 = set mode, 01 = USB, 00 = filter)")
            let cmd1: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x06, 0x01, 0x00, 0xFD]
            try await transport.write(Data(cmd1))
            try await Task.sleep(nanoseconds: 500_000_000)
            if let resp1 = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp1.map { String(format: "%02X", $0) }.joined(separator: " "))")
                if resp1.contains(0xFA) {
                    print("❌ NAK - Radio rejected")
                } else if resp1.contains(0xFB) {
                    print("✓ ACK - Radio accepted")
                }
            }
            print()

            // Test 2: Mode without filter byte
            print("TEST 2: Set USB WITHOUT filter byte")
            print("Command: FE FE 88 E0 06 01 FD")
            print("  (06 = set mode, 01 = USB, no filter)")
            let cmd2: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x06, 0x01, 0xFD]
            try await transport.write(Data(cmd2))
            try await Task.sleep(nanoseconds: 500_000_000)
            if let resp2 = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp2.map { String(format: "%02X", $0) }.joined(separator: " "))")
                if resp2.contains(0xFA) {
                    print("❌ NAK - Radio rejected")
                } else if resp2.contains(0xFB) {
                    print("✓ ACK - Radio accepted")
                }
            }
            print()

            // Test 3: Try command 0x26 (used by some IC-7100 software)
            print("TEST 3: Set USB using command 0x26")
            print("Command: FE FE 88 E0 26 00 01 FD")
            print("  (26 = select mode, 00 = subcommand, 01 = USB)")
            let cmd3: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x26, 0x00, 0x01, 0xFD]
            try await transport.write(Data(cmd3))
            try await Task.sleep(nanoseconds: 500_000_000)
            if let resp3 = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp3.map { String(format: "%02X", $0) }.joined(separator: " "))")
                if resp3.contains(0xFA) {
                    print("❌ NAK - Radio rejected")
                } else if resp3.contains(0xFB) {
                    print("✓ ACK - Radio accepted")
                }
            }
            print()

            // Test 4: Read mode to see current state
            print("TEST 4: Read current mode")
            print("Command: FE FE 88 E0 04 FD")
            print("  (04 = read mode)")
            let cmd4: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x04, 0xFD]
            try await transport.write(Data(cmd4))
            try await Task.sleep(nanoseconds: 500_000_000)
            if let resp4 = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp4.map { String(format: "%02X", $0) }.joined(separator: " "))")
                // Skip echo, read actual response
                if let resp4b = try? await transport.read(timeout: 1.0) {
                    print("  (after echo): \(resp4b.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    let bytes = Array(resp4b)
                    if bytes.count >= 7 && bytes[4] == 0x04 {
                        let modeCode = bytes[5]
                        let filter = bytes.count > 6 ? bytes[6] : 0xFF
                        print("  Mode code: 0x\(String(format: "%02X", modeCode))")
                        if filter != 0xFF {
                            print("  Filter: 0x\(String(format: "%02X", filter))")
                        }
                    }
                }
            }
            print()

            print("👉 QUESTION: What mode is displayed on your radio right now?")
            print("   Mode: ________________")

            await transport.close()
            print("\n✓ Disconnected")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }
}
