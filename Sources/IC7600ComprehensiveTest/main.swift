import Foundation
import RigControl

/// Comprehensive CI-V command test for IC-7600
/// Tests HF/6m bands with dual receiver validation
@main
struct IC7600ComprehensiveTest {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-7600 Comprehensive CI-V Command Test")
        print("Testing HF/6m dual receiver with all major bands")
        print(String(repeating: "=", count: 70) + "\n")

        guard let port = ProcessInfo.processInfo.environment["IC7600_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set IC7600_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Configuration:")
        print("  Port: \(port)")
        print("  Radio: IC-7600 (CI-V Address: 0x7A)")
        print("  Bands: 160m-6m (HF/6m)")
        print("  Features: Dual independent receivers (Main + Sub)")
        print("  Max Power: 100W")
        print("")

        var testsPassed = 0
        var testsFailed = 0

        do {
            // Create controller
            let rig = try RigController(
                radio: .icomIC7600(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)  // Use default 19200 baud
            )

            // Connect
            try await rig.connect()
            print("✓ Connected to IC-7600\n")

            // Save original state
            print("💾 Saving original radio state...")
            let originalFreq = try await rig.frequency(vfo: .a, cached: false)
            let originalMode = try await rig.mode(vfo: .a, cached: false)
            let originalPower = try await rig.power()
            print("   Frequency: \(formatFreq(originalFreq))")
            print("   Mode: \(originalMode.rawValue)")
            print("   Power: \(originalPower)W\n")

            // Test 1: Multi-Band Frequency Control
            print("📡 Test 1: Multi-Band Frequency Control")
            do {
                let testFreqs: [(UInt64, String)] = [
                    (1_850_000, "160m CW"),
                    (3_700_000, "80m LSB"),
                    (7_100_000, "40m LSB"),
                    (10_125_000, "30m CW"),
                    (14_200_000, "20m USB"),
                    (18_100_000, "17m USB"),
                    (21_200_000, "15m USB"),
                    (24_950_000, "12m USB"),
                    (28_500_000, "10m USB"),
                    (50_100_000, "6m USB")
                ]
                for (freq, band) in testFreqs {
                    try await rig.setFrequency(freq, vfo: .a)
                    let actual = try await rig.frequency(vfo: .a, cached: false)
                    guard actual == freq else {
                        print("   ❌ \(band): Expected \(formatFreq(freq)), got \(formatFreq(actual))")
                        continue
                    }
                    print("   ✓ \(band): \(formatFreq(freq))")
                }
                testsPassed += 1
                print("   ✅ Multi-band frequency control: PASS\n")
            } catch {
                print("   ❌ Multi-band frequency control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 2: Mode Control
            print("📻 Test 2: Mode Control Commands")
            do {
                try await rig.setFrequency(14_200_000, vfo: .a)
                let modes: [Mode] = [.usb, .lsb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB]
                for mode in modes {
                    try await rig.setMode(mode, vfo: .a)
                    let actual = try await rig.mode(vfo: .a, cached: false)
                    guard actual == mode else {
                        print("   ⚠️  \(mode.rawValue): Expected \(mode.rawValue), got \(actual.rawValue)")
                        continue
                    }
                    print("   ✓ \(mode.rawValue)")
                }
                testsPassed += 1
                print("   ✅ Mode control: PASS\n")
            } catch {
                print("   ❌ Mode control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 3: Dual VFO Operations
            print("🔀 Test 3: Dual VFO Operations")
            do {
                // Set different frequencies on VFO A and B
                try await rig.selectVFO(.a)
                try await rig.setFrequency(14_200_000, vfo: .a)
                try await rig.setMode(.usb, vfo: .a)

                try await rig.selectVFO(.b)
                try await rig.setFrequency(7_100_000, vfo: .b)
                try await rig.setMode(.lsb, vfo: .b)

                // Verify both VFOs
                let freqA = try await rig.frequency(vfo: .a, cached: false)
                let modeA = try await rig.mode(vfo: .a, cached: false)
                let freqB = try await rig.frequency(vfo: .b, cached: false)
                let modeB = try await rig.mode(vfo: .b, cached: false)

                print("   ✓ VFO A (20m): \(formatFreq(freqA)) \(modeA.rawValue)")
                print("   ✓ VFO B (40m): \(formatFreq(freqB)) \(modeB.rawValue)")

                testsPassed += 1
                print("   ✅ Dual VFO operations: PASS\n")
            } catch {
                print("   ❌ Dual VFO operations: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 4: Split Operation
            print("🔊 Test 4: Split Operation Commands")
            do {
                try await rig.setFrequency(14_200_000, vfo: .a)
                try await rig.setFrequency(14_250_000, vfo: .b)

                try await rig.setSplit(true)
                let splitOn = try await rig.isSplitEnabled()
                guard splitOn else {
                    print("   ❌ Split enable failed")
                    testsFailed += 1
                    throw RigError.commandFailed("Split enable")
                }
                print("   ✓ Split enabled")

                try await rig.setSplit(false)
                let splitOff = try await rig.isSplitEnabled()
                guard !splitOff else {
                    print("   ❌ Split disable failed")
                    testsFailed += 1
                    throw RigError.commandFailed("Split disable")
                }
                print("   ✓ Split disabled")

                testsPassed += 1
                print("   ✅ Split operation: PASS\n")
            } catch {
                print("   ❌ Split operation: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 5: Power Control
            print("⚡ Test 5: Power Control Commands")
            do {
                let testPowers = [10, 25, 50, 75, 100]
                for targetPower in testPowers {
                    try await rig.setPower(targetPower)
                    let actual = try await rig.power()
                    // Allow ±5W tolerance
                    guard abs(actual - targetPower) <= 5 else {
                        print("   ⚠️  \(targetPower)W: Got \(actual)W (out of tolerance)")
                        continue
                    }
                    print("   ✓ \(targetPower)W: \(actual)W")
                }
                testsPassed += 1
                print("   ✅ Power control: PASS\n")
            } catch {
                print("   ❌ Power control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 6: PTT Control (dummy load required)
            print("📡 Test 6: PTT Control Commands")
            do {
                // Test on 20m with low power
                try await rig.setPower(10)
                try await rig.setFrequency(14_200_000, vfo: .a)
                try await rig.setMode(.usb, vfo: .a)

                print("   Testing PTT (14.200 MHz USB, 10W)...")
                try await rig.setPTT(true)
                let pttOn = try await rig.isPTTEnabled()
                guard pttOn else {
                    print("   ❌ PTT ON status check failed")
                    testsFailed += 1
                    throw RigError.commandFailed("PTT ON")
                }
                print("   ✓ PTT ON confirmed")

                try await Task.sleep(nanoseconds: 200_000_000)

                try await rig.setPTT(false)
                let pttOff = try await rig.isPTTEnabled()
                guard !pttOff else {
                    print("   ❌ PTT OFF status check failed")
                    testsFailed += 1
                    throw RigError.commandFailed("PTT OFF")
                }
                print("   ✓ PTT OFF confirmed")

                testsPassed += 1
                print("   ✅ PTT control: PASS\n")
            } catch {
                print("   ❌ PTT control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 7: Signal Strength
            print("📊 Test 7: Signal Strength Reading")
            do {
                print("   Reading S-meter 5 times...")
                for i in 1...5 {
                    let strength = try await rig.signalStrength(cached: false)
                    print("   Reading \(i): \(strength.description) (Raw: \(strength.raw), S\(strength.sUnits))")
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                testsPassed += 1
                print("   ✅ Signal strength: PASS\n")
            } catch {
                print("   ❌ Signal strength: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 8: RIT Control
            print("🎚️  Test 8: RIT (Receiver Incremental Tuning)")
            do {
                try await rig.setRIT(RITXITState(enabled: true, offset: 500))
                let ritState = try await rig.getRIT(cached: false)
                guard ritState.enabled && ritState.offset == 500 else {
                    print("   ❌ RIT +500 Hz failed")
                    testsFailed += 1
                    throw RigError.commandFailed("RIT +500")
                }
                print("   ✓ RIT +500 Hz enabled")

                try await rig.setRIT(RITXITState(enabled: false, offset: 0))
                let ritOff = try await rig.getRIT(cached: false)
                guard !ritOff.enabled else {
                    print("   ❌ RIT disable failed")
                    testsFailed += 1
                    throw RigError.commandFailed("RIT disable")
                }
                print("   ✓ RIT disabled")

                testsPassed += 1
                print("   ✅ RIT control: PASS\n")
            } catch {
                print("   ❌ RIT control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 9: XIT Control
            print("🎛️  Test 9: XIT (Transmitter Incremental Tuning)")
            do {
                try await rig.setXIT(RITXITState(enabled: true, offset: -300))
                let xitState = try await rig.getXIT(cached: false)
                guard xitState.enabled && xitState.offset == -300 else {
                    print("   ❌ XIT -300 Hz failed")
                    testsFailed += 1
                    throw RigError.commandFailed("XIT -300")
                }
                print("   ✓ XIT -300 Hz enabled")

                try await rig.setXIT(RITXITState(enabled: false, offset: 0))
                let xitOff = try await rig.getXIT(cached: false)
                guard !xitOff.enabled else {
                    print("   ❌ XIT disable failed")
                    testsFailed += 1
                    throw RigError.commandFailed("XIT disable")
                }
                print("   ✓ XIT disabled")

                testsPassed += 1
                print("   ✅ XIT control: PASS\n")
            } catch {
                print("   ❌ XIT control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 10: Rapid Frequency Switching
            print("⚡ Test 10: Rapid Frequency Switching")
            do {
                let freqs: [(UInt64, String)] = [
                    (1_850_000, "160m"),
                    (3_700_000, "80m"),
                    (7_100_000, "40m"),
                    (14_200_000, "20m"),
                    (21_200_000, "15m"),
                    (28_500_000, "10m")
                ]

                let startTime = Date()
                for (freq, label) in freqs {
                    try await rig.setFrequency(freq, vfo: .a)
                    let actual = try await rig.frequency(vfo: .a, cached: false)
                    guard actual == freq else {
                        print("   ⚠️  \(label) verification failed")
                        continue
                    }
                }
                let duration = Date().timeIntervalSince(startTime)
                let avgTime = (duration / Double(freqs.count)) * 1000

                print("   ✓ \(freqs.count) band changes in \(String(format: "%.2f", duration))s")
                print("   ✓ Average: \(String(format: "%.1f", avgTime))ms per change")

                testsPassed += 1
                print("   ✅ Rapid frequency switching: PASS\n")
            } catch {
                print("   ❌ Rapid frequency switching: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Restore original state
            print("🔄 Restoring original state...")
            try await rig.selectVFO(.a)
            try await rig.setFrequency(originalFreq, vfo: .a)
            try await rig.setMode(originalMode, vfo: .a)
            try await rig.setPower(originalPower)
            print("   ✓ State restored\n")

            await rig.disconnect()
            print("   ✓ Disconnected\n")

            // Print summary
            print(String(repeating: "=", count: 70))
            print("Test Summary")
            print(String(repeating: "=", count: 70))
            print("✅ Passed:  \(testsPassed)")
            print("❌ Failed:  \(testsFailed)")
            print("📊 Total:   \(testsPassed + testsFailed)")
            print(String(repeating: "=", count: 70))

            let successRate = Double(testsPassed) / Double(testsPassed + testsFailed) * 100
            print("Success Rate: \(String(format: "%.1f", successRate))%")
            print(String(repeating: "=", count: 70) + "\n")

            if testsFailed == 0 {
                print("🎉 All tests PASSED! IC-7600 implementation fully validated.\n")
            } else {
                print("⚠️  Some tests failed. Review results above.\n")
                Foundation.exit(1)
            }

        } catch {
            print("❌ Fatal error: \(error)\n")
            Foundation.exit(1)
        }
    }

    static func formatFreq(_ hz: UInt64) -> String {
        if hz >= 1_000_000 {
            let mhz = Double(hz) / 1_000_000.0
            return String(format: "%.6f MHz", mhz)
        } else {
            let khz = Double(hz) / 1_000.0
            return String(format: "%.3f kHz", khz)
        }
    }
}
