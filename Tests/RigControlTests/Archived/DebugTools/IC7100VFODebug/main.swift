import Foundation
import RigControl

/// Debug test for IC-7100 VFO operations
@main
struct IC7100VFODebug {
    static func main() async {
        print("═══════════════════════════════════════════════════════════")
        print("IC-7100 VFO Operation Debug Test")
        print("═══════════════════════════════════════════════════════════\n")

        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: "/dev/cu.usbserial-2110", baudRate: 19200)
        )

        do {
            try await rig.connect()
            print("✓ Connected to IC-7100\n")

            // Test 1: Direct VFO selection using selectVFO
            print("══ Test 1: Direct VFO Selection ══")
            print("Attempting to select VFO A...")
            try await rig.selectVFO(.a)
            print("✓ VFO A selected")
            try await Task.sleep(for: .seconds(1))

            print("\nAttempting to select VFO B...")
            try await rig.selectVFO(.b)
            print("✓ VFO B selected")
            try await Task.sleep(for: .seconds(1))

            print("\nAttempting to select VFO A again...")
            try await rig.selectVFO(.a)
            print("✓ VFO A selected again\n")

            // Test 2: Frequency setting with VFO parameter
            print("══ Test 2: Frequency Setting with VFO Parameter ══")
            let freq1: UInt64 = 14_200_000  // 20m
            let freq2: UInt64 = 7_100_000   // 40m

            print("Setting VFO A to \(formatFrequency(freq1))...")
            try await rig.setFrequency(freq1, vfo: .a)
            try await Task.sleep(for: .milliseconds(500))

            print("Reading VFO A frequency...")
            let readFreqA1 = try await rig.frequency(vfo: .a, cached: false)
            print("VFO A frequency: \(formatFrequency(readFreqA1))")

            print("\nSetting VFO B to \(formatFrequency(freq2))...")
            try await rig.setFrequency(freq2, vfo: .b)
            try await Task.sleep(for: .milliseconds(500))

            print("Reading VFO B frequency...")
            let readFreqB1 = try await rig.frequency(vfo: .b, cached: false)
            print("VFO B frequency: \(formatFrequency(readFreqB1))")

            print("\nReading VFO A again...")
            let readFreqA2 = try await rig.frequency(vfo: .a, cached: false)
            print("VFO A frequency: \(formatFrequency(readFreqA2))")

            // Test 3: Check if frequencies are independent
            print("\n══ Test 3: VFO Independence Check ══")
            if readFreqA1 == readFreqA2 && readFreqA1 == freq1 {
                print("✓ VFO A maintained its frequency (\(formatFrequency(freq1)))")
            } else {
                print("✗ VFO A frequency changed unexpectedly")
                print("  Expected: \(formatFrequency(freq1))")
                print("  Got: \(formatFrequency(readFreqA2))")
            }

            if readFreqB1 == freq2 {
                print("✓ VFO B set to correct frequency (\(formatFrequency(freq2)))")
            } else {
                print("✗ VFO B frequency incorrect")
                print("  Expected: \(formatFrequency(freq2))")
                print("  Got: \(formatFrequency(readFreqB1))")
            }

            print("\n👁️  VISUAL CHECK:")
            print("Look at your IC-7100 display:")
            print("- Press the [A/B] button to switch between VFOs")
            print("- VFO A should show: \(formatFrequency(freq1))")
            print("- VFO B should show: \(formatFrequency(freq2))")
            print("\nAre both VFOs showing the correct frequencies? (Press Enter)")
            _ = readLine()

            await rig.disconnect()
            print("\n✓ Test complete")

        } catch {
            print("✗ Error: \(error)")
            await rig.disconnect()
        }
    }

    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.3f MHz", mhz)
    }
}
