import Foundation
import RigControl

/// Test IC-7100 with direct CI-V commands (bypassing VFO selection)
@main
struct IC7100RawTest {
    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║        IC-7100 Raw CI-V Test                               ║")
        print("║        Testing direct frequency read (no VFO select)      ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        // Test reading frequency without VFO selection
        await testDirectFrequencyRead()
    }

    static func testDirectFrequencyRead() async {
        print("Testing direct frequency read on /dev/cu.usbserial-2110...")
        print()

        // We'll use the transport layer directly
        let config = SerialConfiguration(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)

        do {
            try await transport.open()
        } catch {
            print("❌ Failed to open serial port: \(error)")
            return
        }

        // Send a simple frequency read command (0x03) without VFO selection
        // Frame format: FE FE 88 E0 03 FD
        // FE FE = preamble
        // 88 = IC-7100 address
        // E0 = controller address
        // 03 = read frequency command
        // FD = terminator

        let command: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x03, 0xFD]

        print("Sending CI-V command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("  (Read frequency command)")
        print()

        do {
            try await transport.write(Data(command))
            print("✓ Command sent")
            print()

            // Wait for response
            print("Waiting for response...")
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms

            if let response = try? await transport.read(timeout: 2.0) {
                print("✓ Got response!")
                print("  Raw bytes: \(response.map { String(format: "%02X", $0) }.joined(separator: " "))")
                print()

                // Parse the response
                if response.count >= 6 {
                    let bytes = Array(response)

                    // Check for ACK/NAK
                    if bytes.contains(0xFB) {
                        print("  ✓ Radio sent ACK (acknowledged)")
                    } else if bytes.contains(0xFA) {
                        print("  ✗ Radio sent NAK (rejected)")
                    }

                    // Look for frequency data
                    // Format: FE FE E0 88 03 [5 bytes BCD freq] FD
                    if bytes.count >= 11 && bytes[4] == 0x03 {
                        let freqBytes = Array(bytes[5...9])
                        print("  Frequency bytes (BCD): \(freqBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")

                        // Decode BCD frequency
                        let freq = decodeBCDFrequency(freqBytes)
                        print("  🎉 Decoded frequency: \(formatFrequency(freq))")
                    }
                } else {
                    print("  Response too short to parse")
                }
            } else {
                print("  ✗ No response (timeout)")
            }

        } catch {
            print("❌ Error: \(error)")
        }

        await transport.close()
    }

    static func decodeBCDFrequency(_ bytes: [UInt8]) -> UInt64 {
        // BCD decoding: each byte contains 2 decimal digits
        var freq: UInt64 = 0
        for (index, byte) in bytes.enumerated() {
            let low = UInt64(byte & 0x0F)
            let high = UInt64((byte >> 4) & 0x0F)
            let multiplier = UInt64(pow(100.0, Double(index)))
            freq += (high * 10 + low) * multiplier
        }
        return freq
    }

    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
