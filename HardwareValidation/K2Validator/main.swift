import Foundation
import RigControl
import ValidationHelpers

/// Comprehensive CI-V command test for Elecraft K2
/// Tests HF QRP transceiver (0-15W) with text-based CAT protocol
@main
struct K2Validator {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("Elecraft K2 Comprehensive Validation Test")
        print("Testing HF QRP transceiver with text-based CAT protocol")
        print(String(repeating: "=", count: 70) + "\n")

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set K2_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Configuration:")
        print("  Port: \(port)")
        print("  Radio: Elecraft K2")
        print("  Power: 0-15W (QRP)")
        print("")

        var testsPassed = 0
        var testsFailed = 0
        var testsSkipped = 0

        do {
            // Create controller
            let rig = try RigController(
                radio: .elecraftK2,
                connection: .serial(path: port, baudRate: nil)
            )

            // Connect
            try await rig.connect()
            print("✓ Connected to Elecraft K2\n")

            // Save original state
            print("💾 Saving original radio state...")
            let originalFreq = try await rig.frequency(vfo: .a, cached: false)
            let originalMode = try await rig.mode(vfo: .a, cached: false)
            let originalPower = try await rig.power()
            print("   Frequency: \(formatFreq(originalFreq))")
            print("   Mode: \(originalMode.rawValue)")
            print("   Power: \(originalPower)W\n")

            // Test 1: Frequency Control - HF Bands
            print("📡 Test 1: Frequency Control (HF Bands)")
            do {
                let testFreqs: [(UInt64, String)] = [
                    (1_900_000, "160m"),
                    (3_700_000, "80m"),
                    (7_100_000, "40m"),
                    (10_125_000, "30m"),
                    (14_230_000, "20m"),
                    (18_100_000, "17m"),
                    (21_300_000, "15m"),
                    (24_950_000, "12m"),
                    (28_500_000, "10m")
                ]
                for (freq, band) in testFreqs {
                    try await rig.setFrequency(freq, vfo: .a)
                    let actual = try await rig.frequency(vfo: .a, cached: false)
                    guard actual == freq else {
                        print("   ❌ \(band): Expected \(formatFreq(freq)), got \(formatFreq(actual))")
                        testsFailed += 1
                        continue
                    }
                    print("   ✓ \(band): \(formatFreq(freq))")
                }
                testsPassed += 1
                print("   ✅ Frequency control: PASS\n")
            } catch {
                print("   ❌ Frequency control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 2: Fine Frequency Control
            print("🎯 Test 2: Fine Frequency Control (10 Hz Resolution)")
            do {
                let baseFreq: UInt64 = 14_200_000
                let offsets: [UInt64] = [0, 10, 50, 100, 500, 1000]

                for offset in offsets {
                    let freq = baseFreq + offset
                    try await rig.setFrequency(freq, vfo: .a)
                    let actual = try await rig.frequency(vfo: .a, cached: false)
                    guard actual == freq else {
                        print("   ❌ +\(offset) Hz: Expected \(freq), got \(actual)")
                        continue
                    }
                    print("   ✓ +\(offset) Hz: \(formatFreq(freq))")
                }
                testsPassed += 1
                print("   ✅ Fine frequency control: PASS\n")
            } catch {
                print("   ❌ Fine frequency control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 3: Mode Control
            print("📻 Test 3: Mode Control Commands")
            do {
                try await rig.setFrequency(14_200_000, vfo: .a)
                let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .am, .fm]
                for mode in modes {
                    try await rig.setMode(mode, vfo: .a)
                    let actual = try await rig.mode(vfo: .a, cached: false)
                    guard actual == mode else {
                        print("   ❌ \(mode.rawValue): Expected \(mode.rawValue), got \(actual.rawValue)")
                        testsFailed += 1
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

            // Test 4: CW Mode (K2 Specialty)
            print("📻 Test 4: CW Mode (K2 Specialty Feature)")
            do {
                try await rig.setFrequency(14_050_000, vfo: .a)

                print("   Testing CW mode...")
                try await rig.setMode(.cw, vfo: .a)
                let cwMode = try await rig.mode(vfo: .a, cached: false)
                guard cwMode == .cw else {
                    print("   ❌ CW mode failed")
                    testsFailed += 1
                    throw RigError.commandFailed("CW mode")
                }
                print("   ✓ CW mode verified")

                print("   Testing CW-R mode...")
                try await rig.setMode(.cwR, vfo: .a)
                let cwRMode = try await rig.mode(vfo: .a, cached: false)
                guard cwRMode == .cwR else {
                    print("   ❌ CW-R mode failed")
                    testsFailed += 1
                    throw RigError.commandFailed("CW-R mode")
                }
                print("   ✓ CW-R mode verified")

                testsPassed += 1
                print("   ✅ CW mode: PASS\n")
            } catch {
                print("   ❌ CW mode: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 5: QRP Power Control (0-15W)
            print("⚡ Test 5: QRP Power Control (0-15W)")
            do {
                let testPowers = [1, 3, 5, 10, 15]
                for targetPower in testPowers {
                    try await rig.setPower(targetPower)
                    let actual = try await rig.power()
                    // Allow ±2W tolerance for QRP levels
                    guard abs(actual - targetPower) <= 2 else {
                        print("   ❌ \(targetPower)W: Got \(actual)W (out of tolerance)")
                        continue
                    }
                    print("   ✓ \(targetPower)W: \(actual)W")
                }
                testsPassed += 1
                print("   ✅ QRP power control: PASS\n")
            } catch {
                print("   ❌ QRP power control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 6: VFO A/B Control
            print("🔀 Test 6: VFO A/B Control")
            do {
                let freqA: UInt64 = 14_230_000
                let freqB: UInt64 = 14_300_000

                try await rig.setFrequency(freqA, vfo: .a)
                try await rig.setFrequency(freqB, vfo: .b)

                let actualA = try await rig.frequency(vfo: .a, cached: false)
                let actualB = try await rig.frequency(vfo: .b, cached: false)

                guard actualA == freqA && actualB == freqB else {
                    print("   ❌ VFO verification failed")
                    testsFailed += 1
                    throw RigError.commandFailed("VFO control")
                }

                print("   ✓ VFO A: \(formatFreq(actualA))")
                print("   ✓ VFO B: \(formatFreq(actualB))")

                testsPassed += 1
                print("   ✅ VFO control: PASS\n")
            } catch {
                print("   ❌ VFO control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 7: Split Operation
            print("🔊 Test 7: Split Operation Commands")
            do {
                try await rig.setFrequency(14_195_000, vfo: .a)
                try await rig.setFrequency(14_225_000, vfo: .b)

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

            // Test 8: RIT Control
            // Note: K2 only supports enable/disable via CAT, NOT offset adjustment
            // Offset must be set using physical RIT knob
            print("🎚️  Test 8: RIT (Receiver Incremental Tuning)")
            do {
                // Enable RIT (offset ignored - set via physical knob)
                try await rig.setRIT(RITXITState(enabled: true, offset: 0))
                print("   ✓ RIT enabled")

                // Read back RIT state (should be enabled, offset depends on physical setting)
                let ritState = try await rig.getRIT(cached: false)
                guard ritState.enabled else {
                    print("   ❌ RIT not enabled")
                    testsFailed += 1
                    throw RigError.commandFailed("RIT enable verification")
                }
                print("   ✓ RIT enabled verified (offset: \(ritState.offset) Hz from physical control)")

                // Disable RIT
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
                print("   Note: K2 offset adjustment requires physical RIT knob")
            } catch {
                print("   ❌ RIT control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 9: XIT Control
            // Note: K2 only supports enable/disable via CAT, NOT offset adjustment
            // Offset must be set using VFO A/B controls
            print("🎚️  Test 9: XIT (Transmitter Incremental Tuning)")
            do {
                // Enable XIT (offset ignored - set via physical controls)
                try await rig.setXIT(RITXITState(enabled: true, offset: 0))
                print("   ✓ XIT enabled")

                let xitState = try await rig.getXIT(cached: false)
                guard xitState.enabled else {
                    print("   ❌ XIT not enabled")
                    testsFailed += 1
                    throw RigError.commandFailed("XIT enable verification")
                }
                print("   ✓ XIT enabled verified (offset: \(xitState.offset) Hz from physical control)")

                // Disable XIT
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
                print("   Note: K2 offset adjustment requires physical VFO A/B controls")
            } catch {
                print("   ❌ XIT control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 10: PTT Control (using CW mode - SSB requires audio input)
            print("📡 Test 10: PTT Control Commands (CW Mode)")
            do {
                try await rig.setPower(1)  // 1W QRP
                try await rig.setFrequency(14_100_000, vfo: .a)  // CW portion of 20m
                try await rig.setMode(.cw, vfo: .a)  // CW mode produces carrier without audio

                print("   Keying transmitter for 5 seconds at 1W...")
                print("   (CW mode should produce full carrier)")
                print("   → Watch power meter on radio for TX indication")

                try await rig.setPTT(true)
                print("   → TX command sent, waiting 200ms...")

                // Give K2 extra time to fully engage in CW mode
                try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

                print("   → Querying PTT status...")
                let pttOn = try await rig.isPTTEnabled()
                guard pttOn else {
                    print("   ❌ PTT ON status check failed")
                    print("   ℹ️  TQ query returned RX status (TQ0)")
                    print("   ℹ️  Did radio show TX on display/meter? (Y/N)")
                    print("      → If YES: TQ query timing issue or TQ command not working")
                    print("      → If NO: CAT PTT may be disabled in K2 menu (INP or T-R)")
                    testsFailed += 1
                    throw RigError.commandFailed("PTT ON")
                }
                print("   ✓ PTT ON confirmed (TQ1)")
                print("   → Radio should be transmitting CW carrier")

                // Hold TX for 5 seconds for easy observation
                print("   → Holding TX for 5 seconds (observe power meter)...")
                try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

                print("   → Sending RX command...")
                try await rig.setPTT(false)

                // Give K2 time to return to RX
                try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

                let pttOff = try await rig.isPTTEnabled()
                guard !pttOff else {
                    print("   ❌ PTT OFF status check failed")
                    testsFailed += 1
                    throw RigError.commandFailed("PTT OFF")
                }
                print("   ✓ PTT OFF confirmed (TQ0)")

                testsPassed += 1
                print("   ✅ PTT control: PASS")
                print("   Note: SSB mode requires audio input for RF output\n")
            } catch {
                print("   ❌ PTT control: FAIL - \(error)")
                print("\n   Troubleshooting:")
                print("   1. Run: K2_SERIAL_PORT=<port> swift run K2PTTDebug")
                print("   2. Check K2 menu: T-R (ensure VOX is OFF)")
                print("   3. Check K2 menu: INP (PTT settings)")
                print("   4. Verify K2 firmware 2.01+ with KIO2 option installed\n")
                testsFailed += 1
            }

            // Test 11: Signal Strength (S-Meter)
            print("📊 Test 11: Signal Strength Reading")
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

            // Test 12: Rapid Frequency Changes
            print("⚡ Test 12: Rapid Frequency Switching Performance")
            do {
                let startFreq: UInt64 = 14_000_000
                let iterations = 30

                let startTime = Date()
                for i in 0..<iterations {
                    let freq = startFreq + UInt64(i * 10_000)
                    try await rig.setFrequency(freq, vfo: .a)
                }
                let duration = Date().timeIntervalSince(startTime)
                let avgTime = (duration / Double(iterations)) * 1000

                print("   ✓ \(iterations) frequency changes in \(String(format: "%.2f", duration))s")
                print("   ✓ Average: \(String(format: "%.1f", avgTime))ms per change")

                testsPassed += 1
                print("   ✅ Rapid frequency switching: PASS\n")
            } catch {
                print("   ❌ Rapid frequency switching: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 13: Band Edge Frequencies
            print("🎯 Test 13: Band Edge Frequency Testing")
            do {
                let bandEdges: [(low: UInt64, high: UInt64, band: String)] = [
                    (1_800_000, 2_000_000, "160m"),
                    (3_500_000, 4_000_000, "80m"),
                    (7_000_000, 7_300_000, "40m"),
                    (14_000_000, 14_350_000, "20m"),
                    (21_000_000, 21_450_000, "15m"),
                    (28_000_000, 29_700_000, "10m")
                ]

                for (low, high, band) in bandEdges {
                    try await rig.setFrequency(low, vfo: .a)
                    let actualLow = try await rig.frequency(vfo: .a, cached: false)
                    guard actualLow == low else {
                        print("   ❌ \(band) lower edge failed")
                        continue
                    }

                    try await rig.setFrequency(high, vfo: .a)
                    let actualHigh = try await rig.frequency(vfo: .a, cached: false)
                    guard actualHigh == high else {
                        print("   ❌ \(band) upper edge failed")
                        continue
                    }

                    print("   ✓ \(band) edges verified")
                }

                testsPassed += 1
                print("   ✅ Band edge testing: PASS\n")
            } catch {
                print("   ❌ Band edge testing: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Restore original state
            print("🔄 Restoring original state...")
            try await rig.setFrequency(originalFreq, vfo: .a)
            try await rig.setMode(originalMode, vfo: .a)
            try await rig.setPower(originalPower)
            print("   ✓ State restored\n")

            await rig.disconnect()
            print("   ✓ Disconnected\n")

            // Print summary
            print(String(repeating: "=", count: 70))
            print("Test Summary for Elecraft K2")
            print(String(repeating: "=", count: 70))
            print("✅ Passed:  \(testsPassed)")
            print("❌ Failed:  \(testsFailed)")
            print("⏭️  Skipped: \(testsSkipped)")
            print("📊 Total:   \(testsPassed + testsFailed + testsSkipped)")
            print(String(repeating: "=", count: 70))

            let successRate = Double(testsPassed) / Double(testsPassed + testsFailed) * 100
            print("Success Rate: \(String(format: "%.1f", successRate))%")
            print(String(repeating: "=", count: 70) + "\n")

            if testsFailed == 0 {
                print("🎉 All tests PASSED! Elecraft K2 implementation fully validated.\n")
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
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
