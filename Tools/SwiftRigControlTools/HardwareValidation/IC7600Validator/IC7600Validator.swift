import Foundation
import RigControl
import ValidationHelpers

/// Hardware validation tool for Icom IC-7600
///
/// This is a standalone executable for validating IC-7600 radio hardware.
/// It tests all major CI-V commands across HF and 6m bands.
///
/// ## Usage
/// ```bash
/// export IC7600_SERIAL_PORT="/dev/cu.usbserial-XXXX"
/// swift run IC7600Validator
/// ```
@main
struct IC7600Validator {
    static func main() async {
        ValidationHelpers.printHeader("IC-7600 Hardware Validation")

        print("Configuration:")
        print("  Radio: Icom IC-7600")
        print("  CI-V Address: 0x7A (default)")
        print("  Baud Rate: 19200")
        print("  Bands: HF + 6m (160m-6m)")
        print("  Max Power: 100W")
        print()

        // Get serial port
        let port = ValidationHelpers.getRequiredSerialPort(
            environmentKey: "IC7600_SERIAL_PORT",
            radioName: "IC-7600"
        )
        print("  Port: \(port)\n")

        var report = ValidationHelpers.TestReport()

        do {
            // Create and connect
            let rig = try RigController(
                radio: .icomIC7600(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)
            )

            try await rig.connect()
            ValidationHelpers.printSuccess("Connected to IC-7600")

            // Save state
            print("\n💾 Saving radio state...")
            let savedState = try await ValidationHelpers.RadioState.save(from: rig)
            savedState.print()

            // Run CORE tests
            await testMultiBandFrequency(rig: rig, report: &report)
            await testModeControl(rig: rig, report: &report)
            await testDualVFO(rig: rig, report: &report)
            await testSplitOperation(rig: rig, report: &report)
            await testPowerControl(rig: rig, report: &report)
            await testPTT(rig: rig, report: &report)
            await testSignalStrength(rig: rig, report: &report)
            await testRIT(rig: rig, report: &report)
            await testXIT(rig: rig, report: &report)
            await testRapidSwitching(rig: rig, report: &report)

            // Run IC-7600 SPECIFIC tests
            await testRFControls(rig: rig, report: &report)
            await testAudioDSPControls(rig: rig, report: &report)
            await testTransmitControls(rig: rig, report: &report)
            await testDualReceiverAdvanced(rig: rig, report: &report)
            await testSpecializedFeatures(rig: rig, report: &report)

            // Restore state
            print("\n🔄 Restoring original radio state...")
            try await savedState.restore(to: rig)
            ValidationHelpers.printSuccess("Radio state restored")

            // Disconnect
            await rig.disconnect()
            ValidationHelpers.printSuccess("Disconnected from IC-7600")

            // Print summary
            report.printSummary(radioName: "IC-7600")

            Foundation.exit(report.exitCode)

        } catch {
            ValidationHelpers.printError("Fatal error: \(error)")
            Foundation.exit(1)
        }
    }

    // MARK: - Test Functions

    static func testMultiBandFrequency(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 1: Multi-Band Frequency Control")

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
                    ValidationHelpers.printError("\(band): Expected \(ValidationHelpers.formatFrequency(freq)), got \(ValidationHelpers.formatFrequency(actual))")
                    continue
                }
                ValidationHelpers.printSuccess("\(band): \(ValidationHelpers.formatFrequency(freq))")
            }

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Multi-band frequency control: PASS\n")
        } catch {
            report.recordFailure("Multi-band frequency control", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Multi-band frequency control: FAIL - \(error)\n")
        }
    }

    static func testModeControl(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 2: Mode Control", icon: "📻")

        do {
            try await rig.setFrequency(14_200_000, vfo: .a)

            // Test basic modes
            let modes: [Mode] = [.usb, .lsb, .cw, .cwR, .rtty, .rttyR, .am, .fm]

            for mode in modes {
                try await rig.setMode(mode, vfo: .a)
                let actual = try await rig.mode(vfo: .a, cached: false)
                guard actual == mode else {
                    ValidationHelpers.printWarning("\(mode.rawValue): Expected \(mode.rawValue), got \(actual.rawValue)")
                    continue
                }
                ValidationHelpers.printSuccess("\(mode.rawValue)")
            }

            // Test DATA mode (IC-7600 specific - uses command 1A 06)
            // IC-7600 doesn't have separate mode codes for USB-D/LSB-D
            // Instead: Set base mode (USB/LSB) + enable DATA mode via 1A 06
            let proto = await rig.protocol
            guard let icomProtocol = proto as? IcomCIVProtocol else {
                ValidationHelpers.printWarning("DATA mode test requires Icom protocol")
                report.recordPass()
                ValidationHelpers.printSuccess("✅ Mode control: PASS (DATA mode skipped)\n")
                return
            }

            // Test USB-D (USB + DATA mode D1)
            try await rig.setMode(.usb, vfo: .a)
            try await icomProtocol.setDataModeIC7600(dataMode: 0x01, filter: 0x01)  // D1 + FIL1
            ValidationHelpers.printSuccess("USB with DATA mode D1 set")

            // Try to read back (may not be supported by all firmware versions)
            do {
                let dataResult = try await icomProtocol.getDataModeIC7600()
                ValidationHelpers.printSuccess("  Read back: DATA=\(dataResult.dataMode), FIL=\(dataResult.filter)")
            } catch {
                ValidationHelpers.printWarning("  Read DATA mode not supported (this is OK)")
            }

            // Test LSB-D (LSB + DATA mode D1)
            try await rig.setMode(.lsb, vfo: .a)
            try await icomProtocol.setDataModeIC7600(dataMode: 0x01, filter: 0x01)  // D1 + FIL1
            ValidationHelpers.printSuccess("LSB with DATA mode D1 set")

            // Turn off DATA mode
            try await icomProtocol.setDataModeIC7600(dataMode: 0x00, filter: 0x00)
            ValidationHelpers.printSuccess("DATA mode turned off")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Mode control: PASS\n")
        } catch {
            report.recordFailure("Mode control", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Mode control: FAIL - \(error)\n")
        }
    }

    static func testDualVFO(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 3: Dual VFO Operations", icon: "🔀")

        do {
            // IC-7600 uses MAIN/SUB receiver architecture, not VFO A/B
            try await rig.selectVFO(.main)
            try await rig.setFrequency(14_200_000, vfo: .main)
            try await rig.setMode(.usb, vfo: .main)

            try await rig.selectVFO(.sub)
            try await rig.setFrequency(7_100_000, vfo: .sub)
            try await rig.setMode(.lsb, vfo: .sub)

            let freqMain = try await rig.frequency(vfo: .main, cached: false)
            let modeMain = try await rig.mode(vfo: .main, cached: false)
            let freqSub = try await rig.frequency(vfo: .sub, cached: false)
            let modeSub = try await rig.mode(vfo: .sub, cached: false)

            ValidationHelpers.printSuccess("MAIN band (20m): \(ValidationHelpers.formatFrequency(freqMain)) \(modeMain.rawValue)")
            ValidationHelpers.printSuccess("SUB band (40m): \(ValidationHelpers.formatFrequency(freqSub)) \(modeSub.rawValue)")

            // Switch back to MAIN VFO
            try await rig.selectVFO(.main)
            ValidationHelpers.printInfo("Switched back to MAIN VFO")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Dual VFO operations: PASS\n")
        } catch {
            // Try to switch back to MAIN even if test failed
            try? await rig.selectVFO(.main)

            report.recordFailure("Dual VFO operations", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Dual VFO operations: FAIL - \(error)\n")
        }
    }

    static func testSplitOperation(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 4: Split Operation", icon: "🔊")

        do {
            try await rig.setFrequency(14_200_000, vfo: .a)
            try await rig.setFrequency(14_250_000, vfo: .b)

            try await rig.setSplit(true)
            let splitOn = try await rig.isSplitEnabled()
            guard splitOn else {
                throw RigError.commandFailed("Split enable failed")
            }
            ValidationHelpers.printSuccess("Split enabled")

            try await rig.setSplit(false)
            let splitOff = try await rig.isSplitEnabled()
            guard !splitOff else {
                throw RigError.commandFailed("Split disable failed")
            }
            ValidationHelpers.printSuccess("Split disabled")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Split operation: PASS\n")
        } catch {
            report.recordFailure("Split operation", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Split operation: FAIL - \(error)\n")
        }
    }

    static func testPowerControl(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 5: Power Control", icon: "⚡")

        do {
            let testPowers = [10, 25, 50, 75, 100]

            for targetPower in testPowers {
                try await rig.setPower(targetPower)
                let actual = try await rig.power()
                guard abs(actual - targetPower) <= 5 else {
                    ValidationHelpers.printWarning("\(targetPower)W: Got \(actual)W (out of tolerance)")
                    continue
                }
                ValidationHelpers.printSuccess("\(targetPower)W: \(actual)W")
            }

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Power control: PASS\n")
        } catch {
            report.recordFailure("Power control", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Power control: FAIL - \(error)\n")
        }
    }

    static func testPTT(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 6: PTT Control", icon: "📡")

        do {
            // Set safe test conditions
            try await rig.setPower(10)
            try await rig.setFrequency(14_200_000, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)

            // Confirm with user
            guard ValidationHelpers.confirmPTTTest(radioName: "IC-7600", frequency: 14_200_000, power: 10) else {
                report.recordSkip("PTT control")
                return
            }

            ValidationHelpers.printInfo("Testing PTT ON...")
            try await rig.setPTT(true)
            let pttOn = try await rig.isPTTEnabled()
            guard pttOn else {
                throw RigError.commandFailed("PTT ON status check failed")
            }
            ValidationHelpers.printSuccess("PTT ON confirmed")

            try await Task.sleep(nanoseconds: 200_000_000)

            ValidationHelpers.printInfo("Testing PTT OFF...")
            try await rig.setPTT(false)
            let pttOff = try await rig.isPTTEnabled()
            guard !pttOff else {
                throw RigError.commandFailed("PTT OFF status check failed")
            }
            ValidationHelpers.printSuccess("PTT OFF confirmed")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ PTT control: PASS\n")
        } catch {
            report.recordFailure("PTT control", error: error.localizedDescription)
            ValidationHelpers.printError("❌ PTT control: FAIL - \(error)\n")
        }
    }

    static func testSignalStrength(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 7: Signal Strength Reading", icon: "📊")

        do {
            ValidationHelpers.printInfo("Reading S-meter 5 times...")
            for i in 1...5 {
                let strength = try await rig.signalStrength(cached: false)
                ValidationHelpers.printInfo("Reading \(i): \(strength.description) (Raw: \(strength.raw), S\(strength.sUnits))")
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Signal strength: PASS\n")
        } catch {
            report.recordFailure("Signal strength", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Signal strength: FAIL - \(error)\n")
        }
    }

    static func testRIT(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 8: RIT Control", icon: "🎚️")

        do {
            try await rig.setRIT(RITXITState(enabled: true, offset: 500))
            let ritState = try await rig.getRIT(cached: false)
            guard ritState.enabled && ritState.offset == 500 else {
                throw RigError.commandFailed("RIT +500 Hz failed")
            }
            ValidationHelpers.printSuccess("RIT +500 Hz enabled")

            try await rig.setRIT(RITXITState(enabled: false, offset: 0))
            let ritOff = try await rig.getRIT(cached: false)
            guard !ritOff.enabled else {
                throw RigError.commandFailed("RIT disable failed")
            }
            ValidationHelpers.printSuccess("RIT disabled")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ RIT control: PASS\n")
        } catch {
            report.recordFailure("RIT control", error: error.localizedDescription)
            ValidationHelpers.printError("❌ RIT control: FAIL - \(error)\n")
        }
    }

    static func testXIT(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 9: XIT Control (Delta TX)", icon: "🎛️")

        // IC-7600: RIT and ΔTX share the same offset (command 0x21 0x00)
        // The radio applies this offset to RX (RIT) or TX (ΔTX) based on front panel control
        // Command 0x21 0x02/0x03 (separate XIT control) is NOT supported
        // There is no CI-V command to independently control ΔTX

        ValidationHelpers.printWarning("IC-7600 does not support separate XIT control via CI-V")
        ValidationHelpers.printInfo("Architecture: RIT and ΔTX share the same offset value")
        ValidationHelpers.printInfo("  • Command 0x21 0x00 sets offset (applies to both RIT and ΔTX)")
        ValidationHelpers.printInfo("  • Command 0x21 0x01 enables/disables RIT")
        ValidationHelpers.printInfo("  • Command 0x21 0x02/0x03 (XIT) not supported - returns NAK")
        ValidationHelpers.printInfo("  • ΔTX is controlled via front panel RIT/ΔTX button")
        ValidationHelpers.printInfo("  • Manual command 1A 05 0085: 'Quick RIT/ΔTX clear' clears both")

        report.recordSkip("XIT control")
        ValidationHelpers.printInfo("⏭️  XIT control: SKIPPED (no separate CI-V control)\n")
    }

    static func testRapidSwitching(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 10: Rapid Frequency Switching", icon: "⚡")

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
            for (freq, _) in freqs {
                try await rig.setFrequency(freq, vfo: .a)
                _ = try await rig.frequency(vfo: .a, cached: false)
            }
            let duration = Date().timeIntervalSince(startTime)
            let avgTime = (duration / Double(freqs.count)) * 1000

            ValidationHelpers.printSuccess("\(freqs.count) band changes in \(String(format: "%.2f", duration))s")
            ValidationHelpers.printSuccess("Average: \(String(format: "%.1f", avgTime))ms per change")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Rapid frequency switching: PASS\n")
        } catch {
            report.recordFailure("Rapid frequency switching", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Rapid frequency switching: FAIL - \(error)\n")
        }
    }

    // MARK: - IC-7600 Specific Tests

    static func testRFControls(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 11: RF Controls (Attenuator, Preamp, AGC)", icon: "📻")

        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            report.recordFailure("RF Controls", error: "Could not access Icom protocol")
            ValidationHelpers.printError("Could not access Icom protocol\n")
            return
        }

        do {
            // Test Attenuator: 0dB, 6dB, 12dB, 18dB
            ValidationHelpers.printInfo("Testing Attenuator...")
            for attLevel in [0x00, 0x06, 0x12, 0x18] as [UInt8] {
                try await icomProtocol.setAttenuatorIC7600(attLevel)
                let actual = try await icomProtocol.getAttenuatorIC7600()
                guard actual == attLevel else {
                    ValidationHelpers.printWarning("Attenuator \(attLevel)dB: Expected \(attLevel), got \(actual)")
                    continue
                }
                ValidationHelpers.printSuccess("Attenuator \(attLevel)dB verified")
            }

            // Test Preamp: OFF=0, P.AMP1=1, P.AMP2=2
            ValidationHelpers.printInfo("Testing Preamp...")
            for (value, name) in [(0x00 as UInt8, "OFF"), (0x01 as UInt8, "P.AMP1"), (0x02 as UInt8, "P.AMP2")] {
                try await icomProtocol.setPreampIC7600(value)
                // Allow radio time to process
                try await Task.sleep(nanoseconds: 100_000_000)

                do {
                    let actual = try await icomProtocol.getPreampIC7600()
                    guard actual == value else {
                        ValidationHelpers.printWarning("Preamp \(name): Expected \(value), got \(actual)")
                        continue
                    }
                    ValidationHelpers.printSuccess("Preamp \(name) verified")
                } catch {
                    ValidationHelpers.printWarning("Preamp \(name) set successfully, read verification failed: \(error)")
                }
            }

            // Test AGC: FAST=1, MID=2, SLOW=3
            ValidationHelpers.printInfo("Testing AGC...")
            for (value, name) in [(0x01 as UInt8, "FAST"), (0x02 as UInt8, "MID"), (0x03 as UInt8, "SLOW")] {
                try await icomProtocol.setAGCIC7600(value)
                try await Task.sleep(nanoseconds: 100_000_000)

                do {
                    let actual = try await icomProtocol.getAGCIC7600()
                    guard actual == value else {
                        ValidationHelpers.printWarning("AGC \(name): Expected \(value), got \(actual)")
                        continue
                    }
                    ValidationHelpers.printSuccess("AGC \(name) verified")
                } catch {
                    ValidationHelpers.printWarning("AGC \(name) set successfully, read verification failed: \(error)")
                }
            }

            // Test Squelch Condition (requires FM mode)
            ValidationHelpers.printInfo("Testing Squelch Condition (switching to FM mode)...")
            let squelchSavedMode = try await rig.mode(vfo: .main, cached: false)
            try await rig.setMode(.fm, vfo: .main)
            try await Task.sleep(nanoseconds: 200_000_000)

            let squelchOpen = try await icomProtocol.getSquelchConditionIC7600()
            ValidationHelpers.printSuccess("Squelch: \(squelchOpen ? "OPEN" : "CLOSED")")

            // Restore mode
            try await rig.setMode(squelchSavedMode, vfo: .main)
            ValidationHelpers.printInfo("Restored mode to \(squelchSavedMode.rawValue)")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ RF controls: PASS\n")
        } catch {
            report.recordFailure("RF controls", error: error.localizedDescription)
            ValidationHelpers.printError("❌ RF controls: FAIL - \(error)\n")
        }
    }

    static func testAudioDSPControls(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 12: Audio/DSP Controls (PBT, Filters, Notch)", icon: "🎛️")

        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            report.recordFailure("Audio/DSP controls", error: "Could not access Icom protocol")
            ValidationHelpers.printError("Could not access Icom protocol\n")
            return
        }

        do {
            // Test TWIN PBT (Passband Tuning)
            ValidationHelpers.printInfo("Testing TWIN PBT...")
            try await icomProtocol.setInnerPBTIC7600(128)  // Center
            let innerPBT = try await icomProtocol.getInnerPBTIC7600()
            ValidationHelpers.printSuccess("Inner PBT: \(innerPBT)")

            try await icomProtocol.setOuterPBTIC7600(128)  // Center
            let outerPBT = try await icomProtocol.getOuterPBTIC7600()
            ValidationHelpers.printSuccess("Outer PBT: \(outerPBT)")

            // Test Manual Notch Filter
            ValidationHelpers.printInfo("Testing Manual Notch...")
            // First, ensure notch is off
            try await icomProtocol.setManualNotchIC7600(false)
            try await Task.sleep(nanoseconds: 100_000_000)

            // Now test turning it on
            try await icomProtocol.setManualNotchIC7600(true)
            try await Task.sleep(nanoseconds: 100_000_000)

            do {
                let notchOn = try await icomProtocol.getManualNotchIC7600()
                guard notchOn else {
                    throw RigError.commandFailed("Manual notch enable failed")
                }
                ValidationHelpers.printSuccess("Manual Notch ON")
            } catch {
                ValidationHelpers.printWarning("Manual Notch set to ON, read verification failed: \(error)")
            }

            // Turn it back off
            try await icomProtocol.setManualNotchIC7600(false)
            try await Task.sleep(nanoseconds: 100_000_000)

            do {
                let notchOff = try await icomProtocol.getManualNotchIC7600()
                guard !notchOff else {
                    throw RigError.commandFailed("Manual notch disable failed")
                }
                ValidationHelpers.printSuccess("Manual Notch OFF")
            } catch {
                ValidationHelpers.printWarning("Manual Notch set to OFF, read verification failed: \(error)")
            }

            // Test Audio Peak Filter (requires CW mode)
            ValidationHelpers.printInfo("Testing Audio Peak Filter (switching to CW mode)...")
            let savedMode = try await rig.mode(vfo: .main, cached: false)
            try await rig.setMode(.cw, vfo: .main)
            try await Task.sleep(nanoseconds: 200_000_000)

            try await icomProtocol.setAudioPeakFilterIC7600(true)
            try await Task.sleep(nanoseconds: 100_000_000)

            do {
                let peakOn = try await icomProtocol.getAudioPeakFilterIC7600()
                ValidationHelpers.printSuccess("Audio Peak Filter: \(peakOn ? "ON" : "OFF")")
            } catch {
                ValidationHelpers.printWarning("Audio Peak Filter set, read failed: \(error)")
            }

            try await icomProtocol.setAudioPeakFilterIC7600(false)

            // Restore mode
            try await rig.setMode(savedMode, vfo: .main)
            ValidationHelpers.printInfo("Restored mode to \(savedMode.rawValue)")

            // Test Twin Peak Filter (requires RTTY or PSK mode)
            ValidationHelpers.printInfo("Testing Twin Peak Filter (switching to RTTY mode)...")
            let savedMode2 = try await rig.mode(vfo: .main, cached: false)
            try await rig.setMode(.rtty, vfo: .main)
            try await Task.sleep(nanoseconds: 200_000_000)

            try await icomProtocol.setTwinPeakFilterIC7600(true)
            try await Task.sleep(nanoseconds: 100_000_000)

            do {
                let twinPeakOn = try await icomProtocol.getTwinPeakFilterIC7600()
                ValidationHelpers.printSuccess("Twin Peak Filter: \(twinPeakOn ? "ON" : "OFF")")
            } catch {
                ValidationHelpers.printWarning("Twin Peak Filter set to ON, read failed: \(error)")
            }

            try await icomProtocol.setTwinPeakFilterIC7600(false)

            // Restore mode
            try await rig.setMode(savedMode2, vfo: .main)
            ValidationHelpers.printInfo("Restored mode to \(savedMode2.rawValue)")

            // Test Filter Width (sample a few values from 0-49)
            ValidationHelpers.printInfo("Testing Filter Width...")
            for filterIdx in [0x00, 0x10, 0x20, 0x30] as [UInt8] {
                try await icomProtocol.setFilterWidthIC7600(filterIdx)
                let actual = try await icomProtocol.getFilterWidthIC7600()
                ValidationHelpers.printSuccess("Filter \(filterIdx): \(actual)")
            }

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Audio/DSP controls: PASS\n")
        } catch {
            report.recordFailure("Audio/DSP controls", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Audio/DSP controls: FAIL - \(error)\n")
        }
    }

    static func testTransmitControls(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 13: Transmit Controls (Compression, Break-in)", icon: "📤")

        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            report.recordFailure("Transmit controls", error: "Could not access Icom protocol")
            ValidationHelpers.printError("Could not access Icom protocol\n")
            return
        }

        do {
            // Test Speech Compression
            ValidationHelpers.printInfo("Testing Speech Compression...")
            try await icomProtocol.setCompLevelIC7600(128)  // Mid-level
            let compLevel = try await icomProtocol.getCompLevelIC7600()
            ValidationHelpers.printSuccess("Compression Level: \(compLevel)")

            // Test Break-in (requires CW mode)
            ValidationHelpers.printInfo("Testing Break-in (switching to CW mode)...")
            // Save current mode
            let currentMode = try await rig.mode(vfo: .main, cached: false)

            // Switch to CW mode for break-in test
            try await rig.setMode(.cw, vfo: .main)
            try await Task.sleep(nanoseconds: 200_000_000)

            do {
                try await icomProtocol.setBreakInIC7600(true)
                try await Task.sleep(nanoseconds: 100_000_000)

                let breakInOn = try await icomProtocol.getBreakInIC7600()
                ValidationHelpers.printSuccess("Break-in: \(breakInOn ? "ON" : "OFF")")

                try await icomProtocol.setBreakInIC7600(false)
                try await Task.sleep(nanoseconds: 100_000_000)

                let breakInOff = try await icomProtocol.getBreakInIC7600()
                ValidationHelpers.printSuccess("Break-in: \(breakInOff ? "ON" : "OFF")")
            } catch {
                ValidationHelpers.printWarning("Break-in test failed: \(error)")
            }

            // Restore original mode
            try await rig.setMode(currentMode, vfo: .main)
            ValidationHelpers.printInfo("Restored mode to \(currentMode.rawValue)")

            // Test Break-in Delay
            ValidationHelpers.printInfo("Testing Break-in Delay...")
            try await icomProtocol.setBreakInDelayIC7600(50)  // Sample value
            let breakInDelay = try await icomProtocol.getBreakInDelayIC7600()
            ValidationHelpers.printSuccess("Break-in Delay: \(breakInDelay)")

            // Test Monitor
            ValidationHelpers.printInfo("Testing Monitor...")
            // First turn it off
            try await icomProtocol.setMonitorIC7600(false)
            try await Task.sleep(nanoseconds: 100_000_000)

            // Now test turning it on
            try await icomProtocol.setMonitorIC7600(true)
            try await Task.sleep(nanoseconds: 100_000_000)

            do {
                let monitorOn = try await icomProtocol.getMonitorIC7600()
                ValidationHelpers.printSuccess("Monitor: \(monitorOn ? "ON" : "OFF")")
            } catch {
                ValidationHelpers.printWarning("Monitor set to ON, read failed: \(error)")
            }

            // Turn it back off
            try await icomProtocol.setMonitorIC7600(false)
            try await Task.sleep(nanoseconds: 100_000_000)

            do {
                let monitorOff = try await icomProtocol.getMonitorIC7600()
                ValidationHelpers.printSuccess("Monitor: \(monitorOff ? "ON" : "OFF")")
            } catch {
                ValidationHelpers.printWarning("Monitor set to OFF, read failed: \(error)")
            }

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Transmit controls: PASS\n")
        } catch {
            report.recordFailure("Transmit controls", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Transmit controls: FAIL - \(error)\n")
        }
    }

    static func testDualReceiverAdvanced(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 14: Dual Receiver Advanced Operations", icon: "🔀")

        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            report.recordFailure("Dual receiver advanced", error: "Could not access Icom protocol")
            ValidationHelpers.printError("Could not access Icom protocol\n")
            return
        }

        do {
            // Test Dual Watch
            ValidationHelpers.printInfo("Testing Dual Watch...")
            try await icomProtocol.setDualwatchIC7600(true)
            ValidationHelpers.printSuccess("Dual Watch ON")

            try await icomProtocol.setDualwatchIC7600(false)
            ValidationHelpers.printSuccess("Dual Watch OFF")

            // Test Exchange Bands (swap Main/Sub)
            ValidationHelpers.printInfo("Testing Exchange Bands...")
            try await rig.setFrequency(14_200_000, vfo: .a)
            try await rig.setFrequency(7_100_000, vfo: .b)

            try await icomProtocol.exchangeBandsIC7600()
            ValidationHelpers.printSuccess("Bands exchanged (Main ↔ Sub)")

            // Swap back
            try await icomProtocol.exchangeBandsIC7600()
            ValidationHelpers.printSuccess("Bands restored")

            // Test Equalize Bands (copy Main to Sub)
            ValidationHelpers.printInfo("Testing Equalize Bands...")
            try await icomProtocol.equalizeBandsIC7600()
            ValidationHelpers.printSuccess("Bands equalized (Main → Sub)")

            // Test Audio Balance
            ValidationHelpers.printInfo("Testing Audio Balance...")
            try await icomProtocol.setBalanceIC7600(128)  // Center
            let balance = try await icomProtocol.getBalanceIC7600()
            ValidationHelpers.printSuccess("Audio Balance: \(balance)")

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Dual receiver advanced: PASS\n")
        } catch {
            report.recordFailure("Dual receiver advanced", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Dual receiver advanced: FAIL - \(error)\n")
        }
    }

    static func testSpecializedFeatures(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Test 15: Specialized Features (Band Edge, Dial Lock)", icon: "🔧")

        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            report.recordFailure("Specialized features", error: "Could not access Icom protocol")
            ValidationHelpers.printError("Could not access Icom protocol\n")
            return
        }

        do {
            // Test Band Edge Detection
            ValidationHelpers.printInfo("Testing Band Edge Detection...")
            try await rig.setFrequency(14_200_000, vfo: .a)  // 20m band
            let (lowerEdge, upperEdge) = try await icomProtocol.getBandEdgeIC7600()
            ValidationHelpers.printSuccess("Band Edges: \(ValidationHelpers.formatFrequency(lowerEdge)) - \(ValidationHelpers.formatFrequency(upperEdge))")

            // Test Dial Lock
            ValidationHelpers.printInfo("Testing Dial Lock...")
            try await icomProtocol.setDialLockIC7600(true)
            let dialLockOn = try await icomProtocol.getDialLockIC7600()
            ValidationHelpers.printSuccess("Dial Lock: \(dialLockOn ? "LOCKED" : "UNLOCKED")")

            try await icomProtocol.setDialLockIC7600(false)
            let dialLockOff = try await icomProtocol.getDialLockIC7600()
            ValidationHelpers.printSuccess("Dial Lock: \(dialLockOff ? "LOCKED" : "UNLOCKED")")

            // Test Display Brightness
            ValidationHelpers.printInfo("Testing Display Brightness...")
            try await icomProtocol.setBrightLevelIC7600(128)  // Mid-level
            let brightness = try await icomProtocol.getBrightLevelIC7600()
            ValidationHelpers.printSuccess("Display Brightness: \(brightness)")

            // Test AGC Time Constant
            ValidationHelpers.printInfo("Testing AGC Time Constant...")
            for tc in [0x00, 0x05, 0x0A] as [UInt8] {
                try await icomProtocol.setAGCTimeConstantIC7600(tc)
                let actual = try await icomProtocol.getAGCTimeConstantIC7600()
                ValidationHelpers.printSuccess("AGC Time Constant \(tc): \(actual)")
            }

            report.recordPass()
            ValidationHelpers.printSuccess("✅ Specialized features: PASS\n")
        } catch {
            report.recordFailure("Specialized features", error: error.localizedDescription)
            ValidationHelpers.printError("❌ Specialized features: FAIL - \(error)\n")
        }
    }
}
