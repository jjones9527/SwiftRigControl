import Foundation
import RigControl

/// Interactive live testing program for IC-7100
/// Run this with: swift run IC7100LiveTest
@main
struct IC7100LiveTest {
    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║        IC-7100 Live Testing Program                        ║")
        print("║        SwiftRigControl v1.1.0                              ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        // First, identify which port is CI-V control
        await findControlPort()
    }

    static func findControlPort() async {
        print("TEST 0: IDENTIFY CI-V CONTROL PORT")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
        print("Your IC-7100 has 2 USB ports:")
        print("  • /dev/cu.usbserial-2110")
        print("  • /dev/cu.usbserial-2130")
        print()
        print("We need to identify which one is for CI-V control.")
        print()
        print("Testing /dev/cu.usbserial-2110 first...")
        print()

        let port1 = "/dev/cu.usbserial-2110"
        if await testConnection(port: port1) {
            print("✓ Found CI-V control port: \(port1)")
            print()
            await runAllTests(port: port1)
        } else {
            print("✗ Port 2110 did not respond")
            print()
            print("Testing /dev/cu.usbserial-2130...")
            print()

            let port2 = "/dev/cu.usbserial-2130"
            if await testConnection(port: port2) {
                print("✓ Found CI-V control port: \(port2)")
                print()
                await runAllTests(port: port2)
            } else {
                print("✗ Neither port responded to CI-V commands")
                print()
                print("TROUBLESHOOTING:")
                print("1. Check radio is powered on")
                print("2. Check CI-V settings: MENU > SET > Connectors > CI-V")
                print("   - CI-V USB Port: ON")
                print("   - CI-V Baud Rate: 19200")
                print("3. Try unplugging and reconnecting USB cable")
            }
        }
    }

    static func testConnection(port: String) async -> Bool {
        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: port, baudRate: 19200)
        )

        do {
            try await rig.connect()
            _ = try await rig.frequency(vfo: .a)  // Try to read frequency
            await rig.disconnect()
            return true
        } catch {
            await rig.disconnect()
            return false
        }
    }

    static func runAllTests(port: String) async {
        let rig = RigController(
            radio: .icomIC7100,
            connection: .serial(path: port, baudRate: 19200)
        )

        do {
            try await rig.connect()

            // Phase 1: Basic Connection
            await phase1_BasicConnection(rig: rig)
            await waitForUser()

            // Phase 2: Frequency Control
            await phase2_FrequencyControl(rig: rig)
            await waitForUser()

            // Phase 3: Mode Control
            await phase3_ModeControl(rig: rig)
            await waitForUser()

            // Phase 4: Multi-band Test
            await phase4_MultiBand(rig: rig)
            await waitForUser()

            // Phase 5: Power Control
            await phase5_PowerControl(rig: rig)
            await waitForUser()

            // Phase 6: VFO Operations
            await phase6_VFOOperations(rig: rig)
            await waitForUser()

            // Phase 7: PTT Control
            await phase7_PTTControl(rig: rig)
            await waitForUser()

            // Final summary
            print()
            print("╔════════════════════════════════════════════════════════════╗")
            print("║              ALL TESTS COMPLETED                           ║")
            print("╚════════════════════════════════════════════════════════════╝")

            await rig.disconnect()

        } catch {
            print("❌ FATAL ERROR: \(error)")
            await rig.disconnect()
        }
    }

    // MARK: - Test Phases

    static func phase1_BasicConnection(rig: RigController) async {
        print()
        print("TEST 1: BASIC CONNECTION & RADIO INFO")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        let radioName = await rig.radioName
        let caps = await rig.capabilities

        print("Radio Name: \(radioName)")
        print()
        print("Capabilities:")
        print("  • Has VFO B: \(caps.hasVFOB)")
        print("  • Has Split: \(caps.hasSplit)")
        print("  • Power Control: \(caps.powerControl)")
        print("  • Max Power: \(caps.maxPower)W")
        print("  • Dual Receiver: \(caps.hasDualReceiver)")
        if let freqRange = caps.frequencyRange {
            print("  • Frequency Range: \(formatFrequency(freqRange.min)) - \(formatFrequency(freqRange.max))")
        }
        print()

        print("EXPECTED RESULTS:")
        print("  • Radio Name: IC-7100")
        print("  • Has VFO B: true")
        print("  • Has Split: true")
        print("  • Power Control: true")
        print("  • Max Power: 100W")
        print("  • Dual Receiver: false")
        print("  • Frequency Range: 0.030000 MHz - 500.000000 MHz")
        print()

        do {
            let freq = try await rig.frequency(vfo: .a)
            let mode = try await rig.mode(vfo: .a)

            print("Current Radio State:")
            print("  • VFO A Frequency: \(formatFrequency(freq))")
            print("  • VFO A Mode: \(mode)")
            print()

            print("EXPECTED RESULTS:")
            print("  • Should show whatever frequency is currently displayed on your radio")
            print("  • Should match the mode shown on your radio display")
            print()
            print("✓ Test 1 Complete")
        } catch {
            print("❌ ERROR: \(error)")
        }
    }

    static func phase2_FrequencyControl(rig: RigController) async {
        print()
        print("TEST 2: FREQUENCY CONTROL (HF - 20m Band)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        do {
            print("Setting frequency to 14.230 MHz (20m SSTV calling frequency)...")
            try await rig.setFrequency(14_230_000, vfo: .a)

            // Small delay for radio to update
            try await Task.sleep(nanoseconds: 200_000_000)

            let freq = try await rig.frequency(vfo: .a)
            print("✓ Frequency set")
            print("  • Read back: \(formatFrequency(freq))")
            print()

            print("EXPECTED RESULTS:")
            print("  • Radio display should show: 14.230000 MHz")
            print("  • Band indicator should show: 20m")
            print()
            print("QUESTION: Does your radio display show 14.230 MHz?")
            print("  (The display should have changed)")
        } catch {
            print("❌ ERROR: \(error)")
        }
    }

    static func phase3_ModeControl(rig: RigController) async {
        print()
        print("TEST 3: MODE CONTROL")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        let modes: [Mode] = [.usb, .lsb, .cw, .am, .fm]

        for mode in modes {
            do {
                print("Setting mode to \(mode)...")
                try await rig.setMode(mode, vfo: .a)
                try await Task.sleep(nanoseconds: 300_000_000)

                let readMode = try await rig.mode(vfo: .a)
                print("✓ Mode set to \(readMode)")
                print()
            } catch {
                print("❌ ERROR setting \(mode): \(error)")
                print()
            }
        }

        print("EXPECTED RESULTS:")
        print("  • Radio display should have cycled through: USB → LSB → CW → AM → FM")
        print("  • Each mode should have been displayed briefly on the radio")
        print()
        print("QUESTION: Did you see the mode changing on your radio display?")
    }

    static func phase4_MultiBand(rig: RigController) async {
        print()
        print("TEST 4: MULTI-BAND OPERATION (HF/VHF/UHF)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        let testFrequencies: [(freq: UInt64, band: String, mode: Mode)] = [
            (7_074_000, "40m", .dataUSB),
            (50_313_000, "6m", .usb),
            (144_200_000, "2m", .fm),
            (432_100_000, "70cm", .fm)
        ]

        for test in testFrequencies {
            do {
                print("Setting \(test.band): \(formatFrequency(test.freq)) (\(test.mode))...")
                try await rig.setFrequency(test.freq, vfo: .a)
                try await rig.setMode(test.mode, vfo: .a)
                try await Task.sleep(nanoseconds: 500_000_000)

                let freq = try await rig.frequency(vfo: .a)
                let mode = try await rig.mode(vfo: .a)

                print("✓ Set successfully")
                print("  • Frequency: \(formatFrequency(freq))")
                print("  • Mode: \(mode)")
                print()
            } catch {
                print("❌ ERROR on \(test.band): \(error)")
                print()
            }
        }

        print("EXPECTED RESULTS:")
        print("  • Radio should have switched through 40m → 6m → 2m → 70cm")
        print("  • Display should show each frequency")
        print("  • Band indicator should change for each band")
        print()
        print("QUESTION: Did the radio change bands correctly?")
    }

    static func phase5_PowerControl(rig: RigController) async {
        print()
        print("TEST 5: POWER CONTROL")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        do {
            print("Reading current power level...")
            let currentPower = try await rig.power()
            print("  • Current power: \(currentPower)W")
            print()

            let testPowers = [25, 50, 75, 100]
            for power in testPowers {
                print("Setting power to \(power)W...")
                try await rig.setPower(power)
                try await Task.sleep(nanoseconds: 500_000_000)

                let readPower = try await rig.power()
                print("✓ Power read back as: \(readPower)W")
                print()
            }

            print("EXPECTED RESULTS:")
            print("  • Radio power meter/display should have shown: 25W → 50W → 75W → 100W")
            print("  • Power indicator on display should have changed")
            print()
            print("QUESTION: Did you see the power level changing on the radio?")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }

    static func phase6_VFOOperations(rig: RigController) async {
        print()
        print("TEST 6: VFO A/B OPERATIONS")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        do {
            print("Setting VFO A to 14.200 MHz...")
            try await rig.setFrequency(14_200_000, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)

            print("Setting VFO B to 14.205 MHz...")
            try await rig.setFrequency(14_205_000, vfo: .b)
            try await rig.setMode(.usb, vfo: .b)

            try await Task.sleep(nanoseconds: 500_000_000)

            let freqA = try await rig.frequency(vfo: .a)
            let freqB = try await rig.frequency(vfo: .b)

            print("✓ VFO setup complete")
            print("  • VFO A: \(formatFrequency(freqA))")
            print("  • VFO B: \(formatFrequency(freqB))")
            print()

            print("EXPECTED RESULTS:")
            print("  • VFO A should show: 14.200 MHz")
            print("  • VFO B should show: 14.205 MHz")
            print("  • Press V/M button on radio to toggle and verify both VFOs")
            print()
            print("QUESTION: Are both VFOs set correctly?")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }

    static func phase7_PTTControl(rig: RigController) async {
        print()
        print("TEST 7: PTT CONTROL (TRANSMIT TEST)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
        print("⚠️  WARNING: This test will key your transmitter!")
        print()
        print("BEFORE PROCEEDING:")
        print("  1. Ensure antenna is connected (or dummy load)")
        print("  2. Verify you're on a clear frequency")
        print("  3. Set power to a safe level (radio should be at 100W from previous test)")
        print()
        print("The test will:")
        print("  • Wait 5 seconds")
        print("  • Key transmitter for 1 second")
        print("  • Return to receive")
        print()
        print("Waiting 5 seconds before transmitting...")

        for i in (1...5).reversed() {
            print("  \(i)...")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        do {
            print()
            print("Keying transmitter...")
            try await rig.setPTT(true)
            print("✓ PTT ON - Radio should be transmitting NOW")

            try await Task.sleep(nanoseconds: 1_000_000_000)

            try await rig.setPTT(false)
            print("✓ PTT OFF - Radio should be receiving")
            print()

            print("EXPECTED RESULTS:")
            print("  • Red TX LED on radio lit up for 1 second")
            print("  • Display showed TX indicator")
            print("  • SWR meter showed activity (if antenna connected)")
            print("  • Radio returned to receive mode")
            print()
            print("QUESTION: Did the radio transmit for approximately 1 second?")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }

    // MARK: - Helper Functions

    static func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }

    static func waitForUser() async {
        print()
        print("────────────────────────────────────────────────────────────")
        print("Press RETURN to continue to next test...")
        _ = readLine()
    }
}
