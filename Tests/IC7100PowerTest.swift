import Foundation
import RigControl

/// Test IC-7100 power control with percentage-based units
@main
struct IC7100PowerTest {
    static func main() async {
        print("IC-7100 Power Control Test")
        print("===========================\n")

        let config = SerialConfiguration(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)

        // Get IC-7100 capabilities with percentage-based power units
        let capabilities = RadioCapabilitiesDatabase.icomIC7100

        print("Radio: Icom IC-7100")
        print("Max Power: \(capabilities.maxPower)W")
        print("Power Units: \(capabilities.powerUnits)")
        print("Display Unit: \(capabilities.powerUnits.displayUnit)\n")

        do {
            // Create protocol instance
            let protocol_instance = IcomCIVProtocol(
                transport: transport,
                civAddress: 0x88,  // IC-7100 CI-V address
                capabilities: capabilities
            )

            try await protocol_instance.connect()
            print("✓ Connected\n")

            // TEST 1: Read current power level
            print("TEST 1: Reading current power level")
            print("─────────────────────────────────────")
            let currentPower = try await protocol_instance.getPower()
            print("Current power: \(currentPower)%")
            print("Expected: Should be a value between 0-100%")
            print("Previous bug: Was showing ~196W instead of percentage\n")

            // TEST 2: Set power to 50%
            print("TEST 2: Setting power to 50%")
            print("─────────────────────────────────────")
            print("Command: Set power to 50%")
            try await protocol_instance.setPower(50)
            print("✓ Command sent successfully")

            // Wait for radio to update
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read back
            let power50 = try await protocol_instance.getPower()
            print("Read back: \(power50)%")
            print("Expected: ~50% (may vary by ±1-2% due to BCD rounding)")
            print("\n👉 VERIFY: Check your IC-7100 display NOW - does it show 50%?")
            print("Waiting 5 seconds...\n")
            try await Task.sleep(nanoseconds: 5_000_000_000)

            // TEST 3: Set power to 25%
            print("TEST 3: Setting power to 25%")
            print("─────────────────────────────────────")
            print("Command: Set power to 25%")
            try await protocol_instance.setPower(25)
            print("✓ Command sent successfully")

            // Wait for radio to update
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read back
            let power25 = try await protocol_instance.getPower()
            print("Read back: \(power25)%")
            print("Expected: ~25% (may vary by ±1-2% due to BCD rounding)")
            print("\n👉 VERIFY: Check your IC-7100 display NOW - does it show 25%?")
            print("Waiting 5 seconds...\n")
            try await Task.sleep(nanoseconds: 5_000_000_000)

            // TEST 4: Set power to 100%
            print("TEST 4: Setting power to 100%")
            print("─────────────────────────────────────")
            print("Command: Set power to 100%")
            try await protocol_instance.setPower(100)
            print("✓ Command sent successfully")

            // Wait for radio to update
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read back
            let power100 = try await protocol_instance.getPower()
            print("Read back: \(power100)%")
            print("Expected: ~100% (may vary by ±1-2% due to BCD rounding)")
            print("\n👉 VERIFY: Check your IC-7100 display NOW - does it show 100%?")
            print("Waiting 5 seconds...\n")
            try await Task.sleep(nanoseconds: 5_000_000_000)

            // TEST 5: Set power to 10%
            print("TEST 5: Setting power to 10%")
            print("─────────────────────────────────────")
            print("Command: Set power to 10%")
            try await protocol_instance.setPower(10)
            print("✓ Command sent successfully")

            // Wait for radio to update
            try await Task.sleep(nanoseconds: 500_000_000)

            // Read back
            let power10 = try await protocol_instance.getPower()
            print("Read back: \(power10)%")
            print("Expected: ~10% (may vary by ±1-2% due to BCD rounding)")
            print("\n👉 VERIFY: Check your IC-7100 display NOW - does it show 10%?")
            print("Waiting 5 seconds...\n")
            try await Task.sleep(nanoseconds: 5_000_000_000)

            // Restore to 100%
            print("CLEANUP: Restoring power to 100%")
            print("─────────────────────────────────────")
            try await protocol_instance.setPower(100)
            print("✓ Power restored to 100%\n")

            await protocol_instance.disconnect()
            print("✓ Disconnected\n")

            print("╔═══════════════════════════════════════════════════════════╗")
            print("║                TEST RESULTS SUMMARY                       ║")
            print("╚═══════════════════════════════════════════════════════════╝")
            print("")
            print("If all tests passed:")
            print("  • Power values should be displayed as percentages (0-100%)")
            print("  • Radio display should match the percentage values")
            print("  • No more 196W incorrect readings")
            print("")
            print("Conversion details:")
            print("  • CI-V BCD scale: 0-255 represents 0-100%")
            print("  • PowerUnits.percentage.toScale(50) = \(capabilities.powerUnits.toScale(50))")
            print("  • PowerUnits.percentage.fromScale(128) = \(capabilities.powerUnits.fromScale(128))%")
            print("")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }
}
