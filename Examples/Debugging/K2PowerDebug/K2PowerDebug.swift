import Foundation
import RigControl

/// Debug tool to test K2 power control and understand the response format
@main
struct K2PowerDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("K2 Power Control Debug")
        print(String(repeating: "=", count: 70))

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"] else {
            print("\n❌ Set K2_SERIAL_PORT environment variable")
            print("   Usage: K2_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run K2PowerDebug\n")
            return
        }

        print("\nPort: \(port)\n")

        do {
            let rig = try RigController(
                radio: .elecraftK2,
                connection: .serial(path: port, baudRate: 4800)
            )

            try await rig.connect()
            print("✅ Connected to K2\n")

            guard let proto = await rig.protocol as? ElecraftProtocol else {
                print("❌ Not an Elecraft protocol")
                return
            }

            let transport = await proto.transport

            // Test different power levels and see raw responses
            let testPowers = [1, 3, 5, 10, 15]

            for watts in testPowers {
                print("Setting power to \(watts)W...")

                // Send PC command (K2 format: PCnnn where nnn is watts 000-015)
                let command = String(format: "PC%03d", watts)
                print("  Sending: \(command);")

                var commandData = command.data(using: .ascii)!
                commandData.append(0x3B)  // semicolon
                try await transport.write(commandData)

                // K2 doesn't echo SET commands
                try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

                // Now query the power
                print("  Querying: PC;")
                commandData = "PC;".data(using: .ascii)!
                try await transport.write(commandData)

                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  Response: \(response)")

                // Parse the response
                if response.hasPrefix("PC"), response.count >= 5 {
                    let startIdx = response.index(response.startIndex, offsetBy: 2)
                    let endIdx = response.index(startIdx, offsetBy: 3)
                    let powerStr = String(response[startIdx..<endIdx])

                    if let powerValue = Int(powerStr) {
                        print("  Parsed value: \(powerValue)")
                        print("  Interpretation:")
                        print("    As watts: \(powerValue)W")
                        print("    As percentage: \(powerValue)%")
                    }
                }

                print("")
                try await Task.sleep(nanoseconds: 200_000_000)  // 200ms between tests
            }

            // Additional test: Check what the K2 considers "percentage"
            print(String(repeating: "-", count: 70))
            print("Testing K2 percentage hypothesis...")
            print("")

            // According to K2 docs, the format might be:
            // - 000-015 for direct watts in QRP mode
            // - OR 000-100 for percentage

            print("Test: Set to 100 (if percentage, would be 15W max)")
            var command = "PC100;".data(using: .ascii)!
            try await transport.write(command)
            try await Task.sleep(nanoseconds: 100_000_000)

            print("  Querying: PC;")
            command = "PC;".data(using: .ascii)!
            try await transport.write(command)

            let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
            print("  Response: \(response)")

            print("")

            // Reset to 5W
            print("Resetting to 5W for safety...")
            command = "PC005;".data(using: .ascii)!
            try await transport.write(command)
            try await Task.sleep(nanoseconds: 100_000_000)

            await rig.disconnect()
            print("\n✅ Disconnected\n")

            print(String(repeating: "=", count: 70))
            print("Analysis")
            print(String(repeating: "=", count: 70))
            print("""
            K2 Power Control Format (from manual):

            Basic SET/RSP format: PCnnn; where nnn is:
              - 000-015 watts (QRP mode, K2 standard)
              - 000-150 watts (QRO mode, K2/100 only)

            Extended format: PCnnnx; where x is range selector:
              - x=0: QRP range (0.1-15.0W)
              - x=1: QRO range (1-110W, K2/100 only)

            Our current implementation assumes percentage (000-100), which is
            WRONG for the K2. We need K2-specific power handling.
            """)
            print(String(repeating: "=", count: 70) + "\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
