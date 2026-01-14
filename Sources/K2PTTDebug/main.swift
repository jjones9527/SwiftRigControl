import Foundation
import RigControl

/// Debug tool to test K2 PTT control (TX/RX commands)
@main
struct K2PTTDebug {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("K2 PTT Control Debug")
        print(String(repeating: "=", count: 70))

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"] else {
            print("\n❌ Set K2_SERIAL_PORT environment variable")
            print("   Usage: K2_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run K2PTTDebug\n")
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

            // First, check current mode
            print("Checking current mode...")
            var command = "MD;".data(using: .ascii)!
            try await transport.write(command)
            var responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            var response = String(data: responseData.dropLast(), encoding: .ascii) ?? "<non-ASCII>"
            print("  Current mode: \(response)")

            // Set to USB mode if not already (PTT only works in SSB/RTTY)
            if !response.contains("MD2") {
                print("\n  Setting mode to USB (required for PTT)...")
                command = "MD2;".data(using: .ascii)!
                try await transport.write(command)
                try await Task.sleep(nanoseconds: 100_000_000)  // 100ms K2 delay
                print("  ✅ Mode set to USB")
            }

            print("")

            // Test 1: Check initial TX/RX status
            print("Test 1: Check initial TX/RX status")
            command = "TQ;".data(using: .ascii)!
            try await transport.write(command)
            responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            response = String(data: responseData.dropLast(), encoding: .ascii) ?? "<non-ASCII>"
            print("  Response: \(response)")
            let initialTX = response.contains("TQ1")
            print("  Status: \(initialTX ? "TRANSMITTING" : "RECEIVING")")
            print("")

            // Test 2: Send TX command and observe
            print("Test 2: Send TX command - 5 SECOND TEST")
            print("  Sending: TX;")
            command = "TX;".data(using: .ascii)!
            try await transport.write(command)
            print("  → K2 doesn't echo TX command (normal)")

            // K2 doesn't echo SET commands, so just wait
            print("  → Waiting 200ms for K2 to process...")
            try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

            // Check status
            print("\n  Querying status: TQ;")
            command = "TQ;".data(using: .ascii)!
            try await transport.write(command)
            responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            response = String(data: responseData.dropLast(), encoding: .ascii) ?? "<non-ASCII>"
            print("  Response: '\(response);'")
            let afterTX = response.contains("TQ1")
            print("  TQ Status: \(afterTX ? "TRANSMITTING (TQ1) ✅" : "RECEIVING (TQ0) ❌")")

            // Hold TX for 5 seconds for observation
            print("\n  ╔═══════════════════════════════════════════════════════════╗")
            print("  ║  HOLDING TX FOR 5 SECONDS - PLAY AUDIO INTO MICROPHONE  ║")
            print("  ╚═══════════════════════════════════════════════════════════╝")
            print("\n  → Watch K2 display for TX indicator")
            print("  → Watch power meter for deflection")
            print("  → Play audio/whistle into microphone NOW!")
            print("  → If power meter shows output, CAT PTT IS WORKING")
            print("")

            for i in 1...5 {
                print("  \(i) second\(i == 1 ? "" : "s") elapsed...")
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            }
            print("\n  → 5 seconds complete")
            print("  → Did you see power output? (This is the key question!)")
            print("")

            // Test 3: Send RX command
            print("Test 3: Send RX command")
            print("  Sending: RX;")
            command = "RX;".data(using: .ascii)!
            try await transport.write(command)

            // K2 doesn't echo SET commands
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

            // Check status
            print("  Querying status: TQ;")
            command = "TQ;".data(using: .ascii)!
            try await transport.write(command)
            responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            response = String(data: responseData.dropLast(), encoding: .ascii) ?? "<non-ASCII>"
            print("  Response: \(response)")
            let afterRX = !response.contains("TQ1")
            print("  Status: \(afterRX ? "RECEIVING ✅" : "TRANSMITTING ❌")")
            print("")

            // Test 4: Try using IF command to check TX status
            print("Test 4: Alternative TX check using IF command")
            print("  Sending: TX;")
            command = "TX;".data(using: .ascii)!
            try await transport.write(command)
            print("  → Waiting 200ms for TX state...")
            try await Task.sleep(nanoseconds: 200_000_000)

            print("\n  Querying: IF;")
            command = "IF;".data(using: .ascii)!
            try await transport.write(command)
            responseData = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
            response = String(data: responseData.dropLast(), encoding: .ascii) ?? "<non-ASCII>"
            print("  Response: '\(response);'")

            // IF format: IF[f]*****+yyyyrx*00tmvspb01*;
            // Position 28 is TX flag
            if response.count >= 29 {
                let txIndex = response.index(response.startIndex, offsetBy: 28)
                let txFlag = response[txIndex]
                print("  → TX flag (position 28): '\(txFlag)'")
                print("  IF Status: \(txFlag == "1" ? "TRANSMITTING ✅" : "RECEIVING ❌")")

                if txFlag == "1" {
                    print("\n  ╔═══════════════════════════════════════════════════════════╗")
                    print("  ║  IF REPORTS TX! HOLDING FOR 5 SECONDS - PLAY AUDIO NOW  ║")
                    print("  ╚═══════════════════════════════════════════════════════════╝")
                    print("")
                    for i in 1...5 {
                        print("  \(i) second\(i == 1 ? "" : "s") elapsed...")
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    print("\n  → Did you see power output with IF command?")
                    print("")
                } else {
                    print("  → IF also reports RX (same as TQ)")
                    print("")
                }
            }

            // Return to RX
            print("  Sending: RX;")
            command = "RX;".data(using: .ascii)!
            try await transport.write(command)
            try await Task.sleep(nanoseconds: 200_000_000)

            await rig.disconnect()
            print("\n✅ Disconnected\n")

            // Summary
            print(String(repeating: "=", count: 70))
            print("Analysis")
            print(String(repeating: "=", count: 70))
            print("""

            K2 PTT Control Requirements (from manual):

            1. TX/RX commands only work in SSB and RTTY modes
            2. Does NOT work in CW or AM modes
            3. K2 does not echo TX/RX SET commands
            4. Use TQ command to query TX/RX status

            Possible issues if PTT didn't work:
            - Radio was in CW mode (PTT doesn't work in CW)
            - Radio has hardware PTT disabled
            - Cable/interface issue
            - Microphone not connected (K2 may not TX without mic)

            """)
            print(String(repeating: "=", count: 70) + "\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
