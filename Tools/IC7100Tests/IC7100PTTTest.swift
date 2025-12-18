import Foundation
import RigControl

/// Test IC-7100 PTT (Push-To-Talk / Transmit) control
@main
struct IC7100PTTTest {
    static func main() async {
        print("IC-7100 PTT Control Test")
        print("=========================\n")

        print("⚠️  WARNING: This test will key your transmitter!")
        print("")
        print("Before proceeding, ensure:")
        print("  1. Antenna or dummy load is connected")
        print("  2. You are on a clear frequency or dummy load")
        print("  3. Power is set to a safe level")
        print("")
        print("Press RETURN to continue, or Ctrl+C to abort...")
        _ = readLine()
        print("")

        let config = SerialConfiguration(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)
        let capabilities = RadioCapabilitiesDatabase.icomIC7100

        do {
            let protocol_instance = IcomCIVProtocol(
                transport: transport,
                civAddress: 0x88,
                capabilities: capabilities
            )

            try await protocol_instance.connect()
            print("✓ Connected\n")

            // TEST 1: Read current PTT status
            print("TEST 1: Reading current PTT status")
            print("─────────────────────────────────────")
            let initialPTT = try await protocol_instance.getPTT()
            print("Current PTT: \(initialPTT ? "TX (transmitting)" : "RX (receiving)")")
            print("Expected: Should be RX (false) unless already transmitting")

            if initialPTT {
                print("")
                print("⚠️  Radio is currently transmitting!")
                print("This test will turn off PTT first...")
                try await protocol_instance.setPTT(false)
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            print("")

            // TEST 2: Enable PTT (transmit) for 2 seconds
            print("TEST 2: Enabling PTT (Transmit)")
            print("─────────────────────────────────────")
            print("⚠️  TRANSMITTING IN 3 SECONDS...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("⚠️  TRANSMITTING IN 2 SECONDS...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("⚠️  TRANSMITTING IN 1 SECOND...")
            try await Task.sleep(nanoseconds: 1_000_000_000)

            print("")
            print(">>> KEYING TRANSMITTER NOW <<<")
            try await protocol_instance.setPTT(true)
            print("✓ PTT enabled (TX)")

            // Verify PTT status
            try await Task.sleep(nanoseconds: 500_000_000)
            let txStatus = try await protocol_instance.getPTT()
            print("PTT status read back: \(txStatus ? "TX" : "RX")")

            if !txStatus {
                print("❌ ERROR: PTT status shows RX but should be TX!")
            } else {
                print("✅ Confirmed: Radio is transmitting")
            }

            print("")
            print("👉 VERIFY: Is your IC-7100 showing TX indicator?")
            print("👉 VERIFY: Is the TX LED lit on the radio?")
            print("")
            print("Transmitting for 2 seconds...")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            // TEST 3: Disable PTT (return to receive)
            print("")
            print("TEST 3: Disabling PTT (Return to Receive)")
            print("─────────────────────────────────────")
            try await protocol_instance.setPTT(false)
            print("✓ PTT disabled (RX)")

            // Verify PTT status
            try await Task.sleep(nanoseconds: 500_000_000)
            let rxStatus = try await protocol_instance.getPTT()
            print("PTT status read back: \(rxStatus ? "TX" : "RX")")

            if rxStatus {
                print("❌ ERROR: PTT status shows TX but should be RX!")
            } else {
                print("✅ Confirmed: Radio is receiving")
            }

            print("")
            print("👉 VERIFY: Is your IC-7100 showing RX (TX indicator off)?")
            print("")

            // TEST 4: Quick PTT toggle test
            print("TEST 4: Quick PTT Toggle Test")
            print("─────────────────────────────────────")
            print("This will toggle PTT 3 times (TX for 0.5s each)")
            print("")

            for i in 1...3 {
                print("Toggle \(i)/3: TX")
                try await protocol_instance.setPTT(true)
                try await Task.sleep(nanoseconds: 500_000_000)

                print("Toggle \(i)/3: RX")
                try await protocol_instance.setPTT(false)
                try await Task.sleep(nanoseconds: 500_000_000)
            }

            print("✓ Toggle test complete")
            print("")
            print("👉 VERIFY: Did you see the TX indicator flash 3 times?")
            print("")

            await protocol_instance.disconnect()
            print("✓ Disconnected\n")

            print("╔═══════════════════════════════════════════════════════════╗")
            print("║                TEST RESULTS SUMMARY                       ║")
            print("╚═══════════════════════════════════════════════════════════╝")
            print("")
            print("If all tests passed:")
            print("  • getPTT() should correctly report TX/RX status")
            print("  • setPTT(true) should key the transmitter")
            print("  • setPTT(false) should return to receive")
            print("  • TX indicator on radio should match PTT state")
            print("")
            print("CI-V PTT Command Details:")
            print("  • Command: 0x1C 0x00")
            print("  • Data: 0x00 = RX, 0x01 = TX")
            print("  • IC-7100 requires sub-command 0x00")
            print("")

        } catch {
            print("❌ ERROR: \(error)")
            print("")
            print("If you see 'commandFailed', the radio rejected the PTT command.")
            print("This could mean:")
            print("  • PTT command format is incorrect for IC-7100")
            print("  • CI-V address is wrong")
            print("  • Radio is in a state that prevents PTT")
        }
    }
}
