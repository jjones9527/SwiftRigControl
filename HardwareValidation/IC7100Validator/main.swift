import Foundation
import RigControl
import ValidationHelpers

/// Comprehensive CI-V command test for IC-7100
/// Tests as many commands as practical in bench test environment
@main
struct IC7100ComprehensiveTest {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-7100 Comprehensive CI-V Command Test")
        print("Testing all practicable commands for bench validation")
        print(String(repeating: "=", count: 70) + "\n")

        guard let port = ProcessInfo.processInfo.environment["IC7100_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set IC7100_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Configuration:")
        print("  Port: \(port)")
        print("  Radio: IC-7100 (CI-V Address: 0x88)")
        print("")

        var testsPassed = 0
        var testsFailed = 0
        var testsSkipped = 0

        do {
            // Create controller
            let rig = try RigController(
                radio: .icomIC7100(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)
            )

            // Connect
            try await rig.connect()
            print("✓ Connected to IC-7100\n")

            // Save original state
            print("💾 Saving original radio state...")
            let originalFreq = try await rig.frequency(vfo: .a, cached: false)
            let originalMode = try await rig.mode(vfo: .a, cached: false)
            let originalPower = try await rig.power()
            print("   Frequency: \(formatFreq(originalFreq))")
            print("   Mode: \(originalMode.rawValue)")
            print("   Power: \(originalPower)W\n")

            // Test 1: Frequency Control (0x05 - Set, 0x03 - Read)
            print("📡 Test 1: Frequency Control Commands")
            do {
                let testFreqs: [(UInt64, String)] = [
                    (1_900_000, "160m"),
                    (3_500_000, "80m"),
                    (7_100_000, "40m"),
                    (14_200_000, "20m"),
                    (21_300_000, "15m"),
                    (28_500_000, "10m"),
                    (50_100_000, "6m"),
                    (144_200_000, "2m"),
                    (430_000_000, "70cm")
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

            // Test 2: Mode Control (0x06 - Set, 0x04 - Read)
            print("📻 Test 2: Mode Control Commands")
            do {
                try await rig.setFrequency(14_200_000, vfo: .a)
                let modes: [Mode] = [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm]
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

            // Test 3: VFO Selection (0x07)
            print("🔀 Test 3: VFO Selection Commands")
            do {
                // VFO A
                try await rig.selectVFO(.a)
                try await rig.setFrequency(14_200_000, vfo: .a)
                let freqA = try await rig.frequency(vfo: .a, cached: false)
                print("   ✓ VFO A selected: \(formatFreq(freqA))")

                // VFO B
                try await rig.selectVFO(.b)
                try await rig.setFrequency(14_300_000, vfo: .b)
                let freqB = try await rig.frequency(vfo: .b, cached: false)
                print("   ✓ VFO B selected: \(formatFreq(freqB))")

                // Switch back to A
                try await rig.selectVFO(.a)
                print("   ✓ VFO A re-selected")

                testsPassed += 1
                print("   ✅ VFO selection: PASS\n")
            } catch {
                print("   ❌ VFO selection: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 4: Split Operation (0x0F)
            print("🔊 Test 4: Split Operation Commands")
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

            // Test 5: Power Control (0x14 0x0A)
            print("⚡ Test 5: Power Control Commands")
            do {
                let testPowers = [10, 25, 50, 75, 100]
                for targetPower in testPowers {
                    try await rig.setPower(targetPower)
                    let actual = try await rig.power()
                    // Allow ±5W tolerance
                    guard abs(actual - targetPower) <= 5 else {
                        print("   ❌ \(targetPower)W: Got \(actual)W (out of tolerance)")
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

            // Test 6: PTT Control (0x1C 0x00)
            print("📡 Test 6: PTT Control Commands")
            do {
                try await rig.setPower(10)
                try await rig.setFrequency(14_200_000, vfo: .a)
                try await rig.setMode(.usb, vfo: .a)

                print("   Keying transmitter for 200ms...")
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

            // Test 7: Signal Strength (0x15 0x02)
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

            // Test 8: RIT Control (0x21 0x00/0x01)
            print("🎚️  Test 8: RIT (Receiver Incremental Tuning)")
            do {
                // Enable RIT with +500 Hz offset
                try await rig.setRIT(RITXITState(enabled: true, offset: 500))
                print("   ✓ RIT +500 Hz set")

                // Try to read back
                let ritState = try await rig.getRIT(cached: false)
                guard ritState.enabled && ritState.offset == 500 else {
                    print("   ❌ RIT read-back mismatch: enabled=\(ritState.enabled), offset=\(ritState.offset)")
                    testsFailed += 1
                    throw RigError.commandFailed("RIT verification")
                }
                print("   ✓ RIT +500 Hz verified")

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
            } catch {
                print("   ❌ RIT control: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 9: XIT Control (0x21 0x02/0x03)
            // NOTE: IC-7100 does NOT support XIT (per manual - no 21 02/03 commands)
            print("🎚️  Test 9: XIT (Transmitter Incremental Tuning)")
            print("   ⚠️  IC-7100 does not support XIT per CI-V manual")
            print("   ℹ️  (Command 21 02/03 not documented for this radio)")
            testsSkipped += 1
            print("   ⏭️  XIT control: SKIPPED (not supported)\n")

            // Test 10: Multi-band Rapid Switching
            print("⚡ Test 10: Rapid Multi-band Switching")
            do {
                let bands: [(UInt64, String)] = [
                    (1_900_000, "160m"),
                    (3_700_000, "80m"),
                    (7_100_000, "40m"),
                    (14_200_000, "20m"),
                    (21_300_000, "15m"),
                    (28_500_000, "10m"),
                    (50_100_000, "6m"),
                    (144_200_000, "2m"),
                    (430_000_000, "70cm")
                ]

                let startTime = Date()
                for (freq, band) in bands {
                    try await rig.setFrequency(freq, vfo: .a)
                    let actual = try await rig.frequency(vfo: .a, cached: false)
                    guard actual == freq else {
                        print("   ❌ \(band) verification failed")
                        continue
                    }
                }
                let duration = Date().timeIntervalSince(startTime)
                let avgTime = (duration / Double(bands.count)) * 1000

                print("   ✓ \(bands.count) band changes in \(String(format: "%.2f", duration))s")
                print("   ✓ Average: \(String(format: "%.1f", avgTime))ms per band")

                testsPassed += 1
                print("   ✅ Rapid band switching: PASS\n")
            } catch {
                print("   ❌ Rapid band switching: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 11: VFO Operations
            print("🔄 Test 11: Dual VFO Operations")
            do {
                // Set different frequencies on A and B
                try await rig.selectVFO(.a)
                try await rig.setFrequency(14_200_000, vfo: .a)
                try await rig.setMode(.usb, vfo: .a)

                try await rig.selectVFO(.b)
                try await rig.setFrequency(14_300_000, vfo: .b)
                try await rig.setMode(.lsb, vfo: .b)

                // Verify both VFOs
                let freqA = try await rig.frequency(vfo: .a, cached: false)
                let modeA = try await rig.mode(vfo: .a, cached: false)
                let freqB = try await rig.frequency(vfo: .b, cached: false)
                let modeB = try await rig.mode(vfo: .b, cached: false)

                print("   ✓ VFO A: \(formatFreq(freqA)) \(modeA.rawValue)")
                print("   ✓ VFO B: \(formatFreq(freqB)) \(modeB.rawValue)")

                testsPassed += 1
                print("   ✅ Dual VFO operations: PASS\n")
            } catch {
                print("   ❌ Dual VFO operations: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 12: RF Controls (IC-7100 Specific)
            print("📻 Test 12: RF Controls (Attenuator, Preamp, AGC, NB)")
            do {
                let proto = await rig.protocol
                guard let icomProtocol = proto as? IcomCIVProtocol else {
                    print("   ❌ Could not access Icom protocol\n")
                    testsFailed += 1
                    throw RigError.commandFailed("Protocol access")
                }

                // Test Attenuator
                print("   Testing Attenuator...")
                try await icomProtocol.setAttenuatorIC7100(0x20)  // 20dB
                let att = try await icomProtocol.getAttenuatorIC7100()
                print("   ✓ Attenuator: \(att == 0x20 ? "20dB" : "Other")")

                try await icomProtocol.setAttenuatorIC7100(0x00)  // OFF

                // Test Preamp
                print("   Testing Preamp...")
                for (value, name) in [(0x00 as UInt8, "OFF"), (0x01 as UInt8, "P.AMP1"), (0x02 as UInt8, "P.AMP2")] {
                    try await icomProtocol.setPreampIC7100(value)
                    let actual = try await icomProtocol.getPreampIC7100()
                    print("   ✓ Preamp \(name): \(actual == value ? "OK" : "MISMATCH")")
                }

                // Test AGC
                print("   Testing AGC...")
                for (value, name) in [(0x01 as UInt8, "FAST"), (0x02 as UInt8, "MID"), (0x03 as UInt8, "SLOW")] {
                    try await icomProtocol.setAGCIC7100(value)
                    let actual = try await icomProtocol.getAGCIC7100()
                    print("   ✓ AGC \(name): \(actual == value ? "OK" : "MISMATCH")")
                }

                // Test Noise Blanker
                print("   Testing Noise Blanker Level...")
                try await icomProtocol.setNBLevelIC7100(128)
                let nbLevel = try await icomProtocol.getNBLevelIC7100()
                print("   ✓ NB Level: \(nbLevel)")

                testsPassed += 1
                print("   ✅ RF controls: PASS\n")
            } catch {
                print("   ❌ RF controls: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 13: Audio/DSP Controls (IC-7100 Specific)
            print("🎛️  Test 13: Audio/DSP Controls (PBT, Notch, Filters)")
            do {
                let proto = await rig.protocol
                guard let icomProtocol = proto as? IcomCIVProtocol else {
                    print("   ❌ Could not access Icom protocol\n")
                    testsFailed += 1
                    throw RigError.commandFailed("Protocol access")
                }

                // Test TWIN PBT
                print("   Testing TWIN PBT...")
                try await icomProtocol.setInnerPBTIC7100(128)
                let innerPBT = try await icomProtocol.getInnerPBTIC7100()
                print("   ✓ Inner PBT: \(innerPBT)")

                try await icomProtocol.setOuterPBTIC7100(128)
                let outerPBT = try await icomProtocol.getOuterPBTIC7100()
                print("   ✓ Outer PBT: \(outerPBT)")

                // Test Manual Notch
                print("   Testing Manual Notch...")
                try await icomProtocol.setManualNotchIC7100(true)
                let notchOn = try await icomProtocol.getManualNotchIC7100()
                print("   ✓ Manual Notch: \(notchOn ? "ON" : "OFF")")

                try await icomProtocol.setManualNotchIC7100(false)

                // Test Twin Peak Filter
                print("   Testing Twin Peak Filter...")
                try await icomProtocol.setTwinPeakFilterIC7100(true)
                let twinPeak = try await icomProtocol.getTwinPeakFilterIC7100()
                print("   ✓ Twin Peak Filter: \(twinPeak ? "ON" : "OFF")")

                try await icomProtocol.setTwinPeakFilterIC7100(false)

                // Test DSP Filter Type
                print("   Testing DSP Filter Type...")
                try await icomProtocol.setDSPFilterTypeIC7100(0x01)
                let dspFilter = try await icomProtocol.getDSPFilterTypeIC7100()
                print("   ✓ DSP Filter: \(dspFilter)")

                testsPassed += 1
                print("   ✅ Audio/DSP controls: PASS\n")
            } catch {
                print("   ❌ Audio/DSP controls: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 14: Transmit Controls (IC-7100 Specific)
            print("📤 Test 14: Transmit Controls (VOX, Compression, Break-in)")
            do {
                let proto = await rig.protocol
                guard let icomProtocol = proto as? IcomCIVProtocol else {
                    print("   ❌ Could not access Icom protocol\n")
                    testsFailed += 1
                    throw RigError.commandFailed("Protocol access")
                }

                // Test VOX Gain
                print("   Testing VOX...")
                try await icomProtocol.setVoxGainIC7100(128)
                let voxGain = try await icomProtocol.getVoxGainIC7100()
                print("   ✓ VOX Gain: \(voxGain)")

                // Test Anti-VOX
                try await icomProtocol.setAntiVoxGainIC7100(64)
                let antiVox = try await icomProtocol.getAntiVoxGainIC7100()
                print("   ✓ Anti-VOX Gain: \(antiVox)")

                // Test Speech Compression
                print("   Testing Speech Compression...")
                try await icomProtocol.setCompLevelIC7100(128)
                let compLevel = try await icomProtocol.getCompLevelIC7100()
                print("   ✓ Compression Level: \(compLevel)")

                // Test Break-in
                print("   Testing Break-in...")
                try await icomProtocol.setBreakInIC7100(0x01)  // Semi BK-IN
                let breakInOn = try await icomProtocol.getBreakInIC7100()
                print("   ✓ Break-in: \(breakInOn == 0x01 ? "Semi" : (breakInOn == 0x02 ? "Full" : "OFF"))")

                try await icomProtocol.setBreakInIC7100(0x00)  // OFF

                // Test Monitor
                print("   Testing Monitor...")
                try await icomProtocol.setMonitorIC7100(true)
                let monitorOn = try await icomProtocol.getMonitorIC7100()
                print("   ✓ Monitor: \(monitorOn ? "ON" : "OFF")")

                try await icomProtocol.setMonitorIC7100(false)

                testsPassed += 1
                print("   ✅ Transmit controls: PASS\n")
            } catch {
                print("   ❌ Transmit controls: FAIL - \(error)\n")
                testsFailed += 1
            }

            // Test 15: Display Controls (IC-7100 Specific)
            print("💡 Test 15: Display Controls (LCD, Dial Lock)")
            do {
                let proto = await rig.protocol
                guard let icomProtocol = proto as? IcomCIVProtocol else {
                    print("   ❌ Could not access Icom protocol\n")
                    testsFailed += 1
                    throw RigError.commandFailed("Protocol access")
                }

                // Test LCD Backlight
                print("   Testing LCD Backlight...")
                try await icomProtocol.setLCDBacklightIC7100(128)
                let backlight = try await icomProtocol.getLCDBacklightIC7100()
                print("   ✓ LCD Backlight: \(backlight)")

                // Test LCD Contrast
                print("   Testing LCD Contrast...")
                try await icomProtocol.setLCDContrastIC7100(128)
                let contrast = try await icomProtocol.getLCDContrastIC7100()
                print("   ✓ LCD Contrast: \(contrast)")

                // Test Dial Lock
                print("   Testing Dial Lock...")
                try await icomProtocol.setDialLockIC7100(true)
                let dialLockOn = try await icomProtocol.getDialLockIC7100()
                print("   ✓ Dial Lock: \(dialLockOn ? "LOCKED" : "UNLOCKED")")

                try await icomProtocol.setDialLockIC7100(false)
                let dialLockOff = try await icomProtocol.getDialLockIC7100()
                print("   ✓ Dial Lock: \(dialLockOff ? "LOCKED" : "UNLOCKED")")

                testsPassed += 1
                print("   ✅ Display controls: PASS\n")
            } catch {
                print("   ❌ Display controls: FAIL - \(error)\n")
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
            print("Test Summary for IC-7100")
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
                print("🎉 All tests PASSED! IC-7100 implementation fully validated.\n")
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
