import Foundation
import RigControl

/// Debug tool to decode K2 IF command response
@main
struct K2IFDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("Elecraft K2 IF Command Response Debug")
        print(String(repeating: "=", count: 70))

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"] else {
            print("\n❌ Set K2_SERIAL_PORT environment variable")
            print("   Usage: K2_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run K2IFDebug\n")
            return
        }

        print("\nPort: \(port)\n")

        do {
            let rig = try RigController(
                radio: .elecraftK2,
                connection: .serial(path: port, baudRate: 4800)
            )

            try await rig.connect()
            print("✅ Connected\n")

            guard let proto = await rig.protocol as? ElecraftProtocol else {
                print("❌ Not an Elecraft protocol")
                return
            }

            let transport = await proto.transport

            // Get IF response
            print("Sending: IF;")
            var command = "IF;".data(using: .ascii)!
            try await transport.write(command)

            let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"

            print("Response: \(response)")
            print("Length: \(response.count) characters")
            print("\nByte-by-byte breakdown:")
            for (index, char) in response.enumerated() {
                let byte = char.asciiValue ?? 0
                print(String(format: "  [%02d] '%@' (0x%02X / %d)",
                             index, String(char), byte, byte))
            }

            print("\nAttempting to parse Kenwood IF format:")
            print("Positions (0-indexed):")
            print("  [00-01]: IF (command)")
            print("  [02-12]: VFO A frequency (11 digits)")
            print("  [13-18]: RIT/XIT offset (+/-00000, 6 chars)")
            print("  [19]   : RIT on/off (0/1)")
            print("  [20]   : XIT on/off (0/1)")
            print("  [21-23]: Memory channel or spaces")
            print("  [24]   : TX/RX status")
            print("  [25]   : Mode")
            print("  [26]   : VFO/Memory")
            print("  [27]   : Scan status")
            print("  [28]   : Split")
            print("  [29]   : Tone/CTCSS")
            print("  [30-31]: Tone number")
            print("  [32]   : Shift")

            if response.count >= 19 {
                let freq = String(response[response.index(response.startIndex, offsetBy: 2)..<response.index(response.startIndex, offsetBy: 13)])
                print("\nFrequency: \(freq)")
            }

            if response.count >= 19 {
                let offsetStart = response.index(response.startIndex, offsetBy: 13)
                let offsetEnd = response.index(offsetStart, offsetBy: 6)
                let offset = String(response[offsetStart..<offsetEnd])
                print("RIT/XIT Offset string: '\(offset)'")

                // Try to parse
                if let offsetValue = Int(offset.trimmingCharacters(in: .whitespaces)) {
                    print("  Parsed as integer: \(offsetValue) Hz")
                } else {
                    print("  Failed to parse as integer")
                    print("  Individual chars:")
                    for (i, char) in offset.enumerated() {
                        let byte = char.asciiValue ?? 0
                        print(String(format: "    [\(i)] '%@' (0x%02X / %d)", String(char), byte, byte))
                    }
                }
            }

            // Now enable RIT and check again
            print("\n" + String(repeating: "=", count: 70))
            print("Enabling RIT...")
            command = "RT1;".data(using: .ascii)!
            try await transport.write(command)
            try await Task.sleep(nanoseconds: 100_000_000)

            print("Sending: IF;")
            command = "IF;".data(using: .ascii)!
            try await transport.write(command)

            let responseData2 = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            let response2 = String(data: responseData2, encoding: .ascii) ?? "<non-ASCII>"

            print("Response: \(response2)")

            if response2.count >= 19 {
                let offsetStart = response2.index(response2.startIndex, offsetBy: 13)
                let offsetEnd = response2.index(offsetStart, offsetBy: 6)
                let offset = String(response2[offsetStart..<offsetEnd])
                print("RIT/XIT Offset string: '\(offset)'")

                if let offsetValue = Int(offset.trimmingCharacters(in: .whitespaces)) {
                    print("  Parsed as integer: \(offsetValue) Hz")
                }
            }

            await rig.disconnect()
            print("\n✅ Disconnected\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
