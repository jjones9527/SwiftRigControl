import Foundation
import RigControl

/// Debug IC-7100 power control at the CI-V protocol level
@main
struct IC7100PowerDebug {
    static func main() async {
        print("IC-7100 Power Control Debug")
        print("============================\n")

        let config = SerialConfiguration(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)

        do {
            try await transport.open()
            try await transport.flush()
            print("✓ Connected\n")

            // TEST 1: Read current power level (raw CI-V)
            print("TEST 1: Read power level (raw CI-V command)")
            print("─────────────────────────────────────")
            print("Command: FE FE 88 E0 14 0A FD")
            print("  (14 0A = read RF power level)")
            let readCmd: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x0A, 0xFD]
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
                if bytes.count >= 8 && bytes[4] == 0x14 && bytes[5] == 0x0A {
                    let bcdLow = bytes[6]
                    let bcdHigh = bytes[7]
                    print("  BCD bytes: \(String(format: "%02X %02X", bcdLow, bcdHigh))")

                    // Decode BCD
                    let lowNibble1 = bcdLow & 0x0F
                    let highNibble1 = (bcdLow >> 4) & 0x0F
                    let lowNibble2 = bcdHigh & 0x0F
                    let highNibble2 = (bcdHigh >> 4) & 0x0F
                    let bcdValue = Int(lowNibble1) + Int(highNibble1) * 10 + Int(lowNibble2) * 100 + Int(highNibble2) * 1000
                    print("  BCD value (decimal): \(bcdValue)")
                    print("  As percentage: \(bcdValue * 100 / 255)%")
                }
            }
            print()

            // TEST 2: Set power to 50% (BCD 127-128)
            print("TEST 2: Set power to 50%")
            print("─────────────────────────────────────")
            let scale50 = (50 * 255) / 100  // = 127
            print("50% -> BCD scale: \(scale50)")

            // Encode to BCD
            let ones = scale50 % 10
            let tens = (scale50 / 10) % 10
            let hundreds = (scale50 / 100) % 10
            let bcdLow = UInt8(ones | (tens << 4))
            let bcdHigh = UInt8(hundreds)

            print("BCD encoding: \(String(format: "%02X %02X", bcdLow, bcdHigh))")
            print("Command: FE FE 88 E0 14 0A \(String(format: "%02X %02X", bcdLow, bcdHigh)) FD")

            let setCmd: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x0A, bcdLow, bcdHigh, 0xFD]
            try await transport.write(Data(setCmd))
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read echo
            if let echo = try? await transport.read(timeout: 1.0) {
                print("Echo: \(echo.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }

            // Read response (ACK/NAK)
            if let resp = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp.map { String(format: "%02X", $0) }.joined(separator: " "))")
                let bytes = Array(resp)
                if bytes.contains(0xFB) {
                    print("✓ ACK - Radio accepted command")
                } else if bytes.contains(0xFA) {
                    print("❌ NAK - Radio rejected command")
                }
            }
            print()

            // TEST 3: Try percentage value directly (without BCD encoding)
            print("TEST 3: Try raw percentage value (50 = 0x32)")
            print("─────────────────────────────────────")
            print("Command: FE FE 88 E0 14 0A 50 00 FD")
            print("  (Testing if IC-7100 expects raw decimal, not BCD)")

            let rawCmd: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x0A, 0x32, 0x00, 0xFD]
            try await transport.write(Data(rawCmd))
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read echo
            if let echo = try? await transport.read(timeout: 1.0) {
                print("Echo: \(echo.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }

            // Read response
            if let resp = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp.map { String(format: "%02X", $0) }.joined(separator: " "))")
                let bytes = Array(resp)
                if bytes.contains(0xFB) {
                    print("✓ ACK - Radio accepted command")
                } else if bytes.contains(0xFA) {
                    print("❌ NAK - Radio rejected command")
                }
            }
            print()

            // TEST 4: Check what format the radio is actually returning
            print("TEST 4: Analyze current power value format")
            print("─────────────────────────────────────")
            print("Re-reading power to see current format...")
            let readCmd2: [UInt8] = [0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x0A, 0xFD]
            try await transport.write(Data(readCmd2))
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read echo
            if let echo = try? await transport.read(timeout: 1.0) {
                print("Echo: \(echo.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }

            // Read response
            if let resp = try? await transport.read(timeout: 1.0) {
                print("Response: \(resp.map { String(format: "%02X", $0) }.joined(separator: " "))")
                let bytes = Array(resp)
                if bytes.count >= 8 && bytes[4] == 0x14 && bytes[5] == 0x0A {
                    let byte1 = bytes[6]
                    let byte2 = bytes[7]
                    print("  Data bytes: \(String(format: "%02X %02X", byte1, byte2))")

                    // Try interpreting as BCD
                    let lowNibble1 = byte1 & 0x0F
                    let highNibble1 = (byte1 >> 4) & 0x0F
                    let lowNibble2 = byte2 & 0x0F
                    let highNibble2 = (byte2 >> 4) & 0x0F
                    let asBCD = Int(lowNibble1) + Int(highNibble1) * 10 + Int(lowNibble2) * 100 + Int(highNibble2) * 1000
                    print("  Interpreted as BCD: \(asBCD)")
                    print("  BCD -> percentage: \(asBCD * 100 / 255)%")

                    // Try interpreting as raw binary
                    let asRaw = Int(byte1) | (Int(byte2) << 8)
                    print("  Interpreted as raw binary (little-endian): \(asRaw)")
                    print("  Raw -> percentage: \(asRaw * 100 / 255)%")

                    // Try as just first byte
                    print("  Just first byte: \(byte1)")
                    print("  First byte -> percentage: \(Int(byte1) * 100 / 255)%")
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
