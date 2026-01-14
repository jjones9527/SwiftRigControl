import Foundation
import RigControl

/// Debug tool to test K2 RIT/XIT commands
/// Tests common Kenwood-compatible CAT commands for RIT and XIT

@main
struct K2RITDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("Elecraft K2 RIT/XIT Command Debug")
        print(String(repeating: "=", count: 70))

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"] else {
            print("\n❌ Set K2_SERIAL_PORT environment variable")
            print("   Usage: K2_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run K2RITDebug\n")
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

            // Test common Kenwood/Elecraft RIT/XIT commands
            let testCommands = [
                // RIT queries and control
                ("RT;", "Query RIT on/off status"),
                ("RC;", "Clear RIT/XIT offset"),
                ("RU;", "RIT offset up"),
                ("RD;", "RIT offset down"),
                ("RO;", "Query RIT offset value"),

                // XIT queries and control
                ("XT;", "Query XIT on/off status"),
                ("XO;", "Query XIT offset value"),

                // Alternative formats
                ("IF;", "Query transceiver information (may include RIT/XIT)"),
            ]

            for (command, description) in testCommands {
                print("Test: \(description)")
                print("  Sending: \(command)")

                let commandData = command.data(using: .ascii)!
                try await transport.write(commandData)

                // Try to read response
                do {
                    let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                    let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                    print("  ✅ Received: \(response)")
                    print("     Length: \(response.count) characters")
                    print("     Bytes: \(responseData.map { String(format: "%02X", $0) }.joined(separator: " "))")
                } catch {
                    print("  ❌ Timeout or error: \(error)")
                }

                print("")

                // Add delay between commands for K2
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            print("\nNow testing SET commands (these may not echo):")

            // Test RIT enable/disable
            print("\nTest: Enable RIT")
            print("  Sending: RT1;")
            var command = "RT1;".data(using: .ascii)!
            try await transport.write(command)
            try await Task.sleep(nanoseconds: 100_000_000)

            // Query if it worked
            print("  Querying RIT status: RT;")
            command = "RT;".data(using: .ascii)!
            try await transport.write(command)
            do {
                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  ✅ Response: \(response)")
            } catch {
                print("  ❌ Timeout")
            }

            print("")

            // Test RIT disable
            print("Test: Disable RIT")
            print("  Sending: RT0;")
            command = "RT0;".data(using: .ascii)!
            try await transport.write(command)
            try await Task.sleep(nanoseconds: 100_000_000)

            // Query if it worked
            print("  Querying RIT status: RT;")
            command = "RT;".data(using: .ascii)!
            try await transport.write(command)
            do {
                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  ✅ Response: \(response)")
            } catch {
                print("  ❌ Timeout")
            }

            await rig.disconnect()
            print("\n✅ Disconnected\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
