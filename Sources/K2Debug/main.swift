import Foundation
import RigControl

/// Simple debug tool to test K2 serial communication
/// Shows raw command/response exchanges

@main
struct K2Debug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("Elecraft K2 Debug Tool - Raw Communication")
        print(String(repeating: "=", count: 70))

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"] else {
            print("\n❌ Set K2_SERIAL_PORT environment variable")
            print("   Usage: K2_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run K2Debug\n")
            return
        }

        print("\nPort: \(port)\n")

        do {
            let rig = try RigController(
                radio: .elecraftK2,
                connection: .serial(path: port, baudRate: 4800)  // K2 default is 4800
            )

            try await rig.connect()
            print("✅ Connected\n")

            guard let proto = await rig.protocol as? ElecraftProtocol else {
                print("❌ Not an Elecraft protocol")
                return
            }

            // Get direct access to transport for raw communication
            let transport = await proto.transport

            print("Testing basic commands:\n")

            // Test 1: Query VFO A frequency
            print("Test 1: Query VFO A frequency")
            print("  Sending: FA;")

            var command = "FA;".data(using: .ascii)!
            try await transport.write(command)

            // Try to read response with semicolon terminator
            do {
                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  Received: \(response)")
                print("  Length: \(response.count) characters")
                print("  Bytes: \(responseData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            } catch {
                print("  ❌ Error: \(error)")
            }

            print("")

            // Test 2: Query mode
            print("Test 2: Query mode")
            print("  Sending: MD;")

            command = "MD;".data(using: .ascii)!
            try await transport.write(command)

            do {
                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  Received: \(response)")
                print("  Length: \(response.count) characters")
                print("  Bytes: \(responseData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            } catch {
                print("  ❌ Error: \(error)")
            }

            print("")

            // Test 3: Query power
            print("Test 3: Query power")
            print("  Sending: PC;")

            command = "PC;".data(using: .ascii)!
            try await transport.write(command)

            do {
                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  Received: \(response)")
                print("  Length: \(response.count) characters")
                print("  Bytes: \(responseData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            } catch {
                print("  ❌ Error: \(error)")
            }

            print("")

            // Test 4: SET command (set frequency)
            print("Test 4: Set VFO A frequency to 14.100 MHz")
            print("  Sending: FA00014100000;")

            command = "FA00014100000;".data(using: .ascii)!
            try await transport.write(command)

            // Try to read response
            do {
                let responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
                let response = String(data: responseData, encoding: .ascii) ?? "<non-ASCII>"
                print("  Received: \(response)")
                print("  Length: \(response.count) characters")
                print("  Bytes: \(responseData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            } catch {
                print("  ❌ Error/Timeout: \(error)")
                print("  Note: K2 may not echo SET commands")
            }

            print("")

            await rig.disconnect()
            print("✅ Disconnected\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
