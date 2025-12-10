import Foundation
import RigControl

/// Debug IC-7100 PTT command responses
@main
struct IC7100PTTDebug {
    static func main() async {
        print("IC-7100 PTT Debug")
        print("==================\n")

        let config = SerialConfiguration(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)

        do {
            try await transport.open()
            try await transport.flush()
            print("✓ Connected\n")

            // TEST 1: Read PTT status (raw command)
            print("TEST 1: Read PTT status (raw CI-V)")
            print("─────────────────────────────────────")
            print("Command: FE FE 88 E0 1C 00 FD")
            print("  (1C 00 = PTT query)")
            let readCmd: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x1C, 0x00, 0xFD]
            try await transport.write(Data(readCmd))
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read echo
            if let echo = try? await transport.read(timeout: 1.0) {
                print("Echo: \(echo.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }

            // Read response
            if let resp = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp.map { String(format: "%02X", $0) }.joined(separator: " "))")
                let bytes = Array(resp)

                // Parse response
                if bytes.count >= 8 {
                    print("  Prefix: FE FE")
                    print("  To: 0x\(String(format: "%02X", bytes[2]))")
                    print("  From: 0x\(String(format: "%02X", bytes[3]))")
                    print("  Command byte 1: 0x\(String(format: "%02X", bytes[4]))")
                    if bytes.count > 5 {
                        print("  Command byte 2: 0x\(String(format: "%02X", bytes[5]))")
                    }
                    if bytes.count > 6 {
                        print("  Data bytes: \(bytes[6..<bytes.count-1].map { String(format: "%02X", $0) }.joined(separator: " "))")
                    }
                    print("  Terminator: 0x\(String(format: "%02X", bytes[bytes.count-1]))")
                }
            }
            print()

            await transport.close()
            print("✓ Disconnected")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }
}
