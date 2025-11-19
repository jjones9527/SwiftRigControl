import Foundation
import RigControl

// Example: Basic rig control with IC-9700
//
// This example demonstrates how to:
// - Connect to a radio
// - Set frequency and mode
// - Control PTT
// - Read radio state

@main
struct BasicUsageExample {
    static func main() async {
        // Configure your radio connection
        let serialPort = "/dev/cu.IC9700"  // Change to your serial port
        let baudRate = 115200

        print("SwiftRigControl - Basic Usage Example")
        print("==========================================\n")

        // Create rig controller
        print("Creating rig controller for IC-9700...")
        let rig = RigController(
            radio: .icomIC9700,
            connection: .serial(path: serialPort, baudRate: baudRate)
        )

        do {
            // Connect to radio
            print("Connecting to radio at \(serialPort)...")
            try await rig.connect()
            print("✓ Connected to \(rig.radioName)\n")

            // Display radio capabilities
            print("Radio Capabilities:")
            print("  - Has VFO B: \(rig.capabilities.hasVFOB)")
            print("  - Has Split: \(rig.capabilities.hasSplit)")
            print("  - Power Control: \(rig.capabilities.powerControl)")
            print("  - Max Power: \(rig.capabilities.maxPower)W")
            print("  - Dual Receiver: \(rig.capabilities.hasDualReceiver)")
            print("")

            // Read current state
            print("Reading current radio state...")
            let currentFreq = try await rig.frequency(vfo: .a)
            let currentMode = try await rig.mode(vfo: .a)
            print("✓ Current frequency: \(formatFrequency(currentFreq))")
            print("✓ Current mode: \(currentMode)\n")

            // Set frequency to 20m SSTV calling frequency
            print("Setting frequency to 14.230 MHz (20m SSTV calling)...")
            try await rig.setFrequency(14_230_000, vfo: .a)
            print("✓ Frequency set\n")

            // Set mode to USB
            print("Setting mode to USB...")
            try await rig.setMode(.usb, vfo: .a)
            print("✓ Mode set\n")

            // Verify settings
            print("Verifying settings...")
            let newFreq = try await rig.frequency(vfo: .a)
            let newMode = try await rig.mode(vfo: .a)
            print("✓ Frequency: \(formatFrequency(newFreq))")
            print("✓ Mode: \(newMode)\n")

            // PTT test (brief key)
            print("Testing PTT control (will key for 1 second)...")
            print("WARNING: Make sure your antenna is connected!")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay

            try await rig.setPTT(true)
            print("✓ PTT ON")

            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            try await rig.setPTT(false)
            print("✓ PTT OFF\n")

            // Power control (if supported)
            if rig.capabilities.powerControl {
                print("Reading RF power level...")
                let power = try await rig.power()
                print("✓ Current power: \(power)W\n")

                print("Setting power to 50W...")
                try await rig.setPower(50)
                print("✓ Power set\n")

                // Read back
                let newPower = try await rig.power()
                print("✓ Verified power: \(newPower)W\n")
            }

            // Disconnect
            print("Disconnecting...")
            await rig.disconnect()
            print("✓ Disconnected\n")

            print("Example completed successfully!")

        } catch RigError.notConnected {
            print("❌ Error: Radio is not connected")
        } catch RigError.timeout {
            print("❌ Error: Radio did not respond - check cable and power")
        } catch RigError.serialPortError(let message) {
            print("❌ Serial port error: \(message)")
            print("   Make sure the port '\(serialPort)' exists and is accessible")
        } catch RigError.commandFailed(let reason) {
            print("❌ Command failed: \(reason)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    // Helper function to format frequency
    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
