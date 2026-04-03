import Foundation
import RigControl

/// Debug tool to capture raw IC-9700 NR Level responses
///
/// This tool sends NR Level read commands and prints the raw hex response
/// to help debug the BCD decoding issue.
///
/// Usage:
///   IC9700_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC9700NRDebug

@main
struct IC9700NRDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-9700 NR Level Response Debug")
        print(String(repeating: "=", count: 70))

        guard let serialPort = ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"] else {
            print("\n❌ Error: IC9700_SERIAL_PORT environment variable not set")
            print("   Usage: IC9700_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run IC9700NRDebug\n")
            return
        }

        do {
            let rig = try RigController(
                radio: .icomIC9700(civAddress: nil),
                connection: .serial(path: serialPort, baudRate: 19200)
            )

            try await rig.connect()
            print("\n✅ Connected to IC-9700\n")

            guard let proto = await rig.protocol as? IcomCIVProtocol else {
                print("❌ Not an Icom protocol")
                return
            }

            // Test sequence: Set known values and read back
            let testValues: [(UInt8, String)] = [
                (0, "0%"),
                (64, "25%"),
                (128, "50%"),
                (192, "75%"),
                (255, "100%")
            ]

            for (value, label) in testValues {
                print("\n" + String(repeating: "-", count: 70))
                print("Setting NR Level to \(label) (value: \(value))")
                print(String(repeating: "-", count: 70))

                // Set the value
                try await proto.setNRLevelIC9700(value)
                print("✅ SET command sent")

                // Wait a bit for radio to update
                try await Task.sleep(for: .milliseconds(100))

                // Test the corrected API
                print("\n📥 Testing corrected getNRLevelIC9700()...")
                do {
                    let readValue = try await proto.getNRLevelIC9700()
                    print("   Read value: \(readValue)")
                    print("   Expected:   \(value)")
                    print("   Match: \(readValue == value ? "✅ YES" : "❌ NO (difference: \(Int(readValue) - Int(value)))")")
                } catch {
                    print("   ❌ Read failed: \(error)")
                }

                // Also show raw bytes for reference
                print("\n📥 Raw bytes for reference...")
                do {
                    // Send raw command
                    let transport = await proto.transport
                    let civAddress: UInt8 = 0xA2

                    // Build command: FE FE A2 E0 14 06 FD
                    let cmd: [UInt8] = [0xFE, 0xFE, civAddress, 0xE0, 0x14, 0x06, 0xFD]
                    try await transport.write(Data(cmd))

                    // Read response
                    let responseData = try await transport.readUntil(terminator: 0xFD, timeout: 2.0)

                    print("\n   📊 Raw Response Bytes:")
                    let bytes = [UInt8](responseData)
                    print("   \(bytes.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
                    print("   Length: \(bytes.count)")

                    // Parse manually
                    // Expected: FE FE E0 A2 [14] [06 BCD0 BCD1] FD (subcommand in data)
                    // or:       FE FE E0 A2 [14 06] [BCD0 BCD1] FD (standard)

                    if bytes.count >= 7 {
                        print("\n   Response format:")
                        for (i, byte) in bytes.enumerated() {
                            let label: String
                            switch i {
                            case 0, 1: label = "Preamble"
                            case 2: label = "From (E0=Controller)"
                            case 3: label = "To (A2=IC-9700)"
                            case bytes.count-1: label = "Terminator (FD)"
                            default: label = "Data[\(i-4)]"
                            }
                            print("   [\(i)] 0x\(String(format: "%02X", byte)) - \(label)")
                        }
                    }
                } catch {
                    print("   ❌ Low-level read failed: \(error)")
                }
            }

            await rig.disconnect()
            print("\n✅ Disconnected\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
