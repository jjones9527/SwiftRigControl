import Foundation
import RigControl

// MARK: - Terminal Colors

enum TerminalColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case bold = "\u{001B}[1m"
}

func colorize(_ text: String, _ color: TerminalColor) -> String {
    return "\(color.rawValue)\(text)\(TerminalColor.reset.rawValue)"
}

// MARK: - User Input Helpers

func readLine(prompt: String) -> String {
    print(prompt, terminator: " ")
    return Swift.readLine() ?? ""
}

func readYesNo(prompt: String) -> Bool {
    while true {
        let input = readLine(prompt: "\(prompt) [y/n]:").lowercased()
        if input == "y" || input == "yes" {
            return true
        } else if input == "n" || input == "no" {
            return false
        }
        print(colorize("Please enter 'y' or 'n'", .yellow))
    }
}

func readInt(prompt: String, min: Int, max: Int) -> Int? {
    let input = readLine(prompt: prompt)
    guard let value = Int(input), value >= min, value <= max else {
        return nil
    }
    return value
}

// MARK: - Available Radios

struct TestRadio {
    let definition: RadioDefinition
    let name: String
    let description: String
}

let availableRadios: [TestRadio] = [
    // Modern SDR Transceivers
    TestRadio(
        definition: .icomIC7300(),
        name: "IC-7300",
        description: "HF/6m SDR Transceiver (VFO A/B)"
    ),
    TestRadio(
        definition: .icomIC7610(),
        name: "IC-7610",
        description: "HF/6m SDR Transceiver (Dual RX, VFO A/B)"
    ),
    TestRadio(
        definition: .icomIC9700(),
        name: "IC-9700",
        description: "VHF/UHF/1.2GHz SDR (2m/70cm/23cm, Main/Sub)"
    ),

    // Multi-Band Transceivers
    TestRadio(
        definition: .icomIC7100(),
        name: "IC-7100",
        description: "HF/VHF/UHF All-Mode (VFO A/B)"
    ),
    TestRadio(
        definition: .icomIC705(),
        name: "IC-705",
        description: "HF/VHF/UHF Portable (VFO A/B)"
    ),
    TestRadio(
        definition: .icomIC9100(),
        name: "IC-9100",
        description: "HF/VHF/UHF All-Mode (Main/Sub)"
    ),

    // HF Transceivers
    TestRadio(
        definition: .icomIC7600(),
        name: "IC-7600",
        description: "HF/6m High-End (Main/Sub)"
    ),
    TestRadio(
        definition: .icomIC7200(),
        name: "IC-7200",
        description: "HF/6m Mid-Range"
    ),
    TestRadio(
        definition: .icomIC7410(),
        name: "IC-7410",
        description: "HF/6m Transceiver"
    ),

    // High-End Flagships
    TestRadio(
        definition: .icomIC7700(),
        name: "IC-7700",
        description: "HF/6m 200W Flagship"
    ),
    TestRadio(
        definition: .icomIC7800(),
        name: "IC-7800",
        description: "HF/6m 200W Flagship (Dual RX)"
    ),

    // Legacy HF Transceivers
    TestRadio(
        definition: .icomIC7000(),
        name: "IC-7000",
        description: "HF/VHF/UHF Mobile"
    ),
    TestRadio(
        definition: .icomIC756PRO(),
        name: "IC-756PRO",
        description: "HF/6m Classic"
    ),
    TestRadio(
        definition: .icomIC756PROII(),
        name: "IC-756PROII",
        description: "HF/6m Classic"
    ),
    TestRadio(
        definition: .icomIC756PROIII(),
        name: "IC-756PROIII",
        description: "HF/6m Classic"
    ),
    TestRadio(
        definition: .icomIC746PRO(),
        name: "IC-746PRO",
        description: "HF/VHF Transceiver"
    ),

    // D-STAR Mobiles
    TestRadio(
        definition: .icomID5100(),
        name: "ID-5100",
        description: "VHF/UHF D-STAR Mobile"
    ),
    TestRadio(
        definition: .icomID4100(),
        name: "ID-4100",
        description: "VHF/UHF D-STAR Mobile"
    ),

    // Receivers
    TestRadio(
        definition: .icomICR8600(),
        name: "IC-R8600",
        description: "Wideband Communications Receiver"
    ),
    TestRadio(
        definition: .icomICR75(),
        name: "IC-R75",
        description: "HF Communications Receiver"
    ),
    TestRadio(
        definition: .icomICR9500(),
        name: "IC-R9500",
        description: "Professional Communications Receiver"
    ),
]

// MARK: - Test Suite

class IcomTestSuite {
    let radio: TestRadio
    let rig: RigController
    let port: String
    let baudRate: Int
    var testsPassed = 0
    var testsFailed = 0
    var failureLog: [String] = []

    init(radio: TestRadio, port: String, baudRate: Int) {
        self.radio = radio
        self.port = port
        self.baudRate = baudRate
        self.rig = RigController(
            radio: radio.definition,
            connection: .serial(path: port, baudRate: baudRate)
        )
    }

    func printHeader(_ text: String) {
        print("\n" + colorize(String(repeating: "=", count: 70), .cyan))
        print(colorize(text, .bold))
        print(colorize(String(repeating: "=", count: 70), .cyan))
    }

    func printTestStart(_ test: String) {
        print("\n" + colorize("▶ TEST: \(test)", .blue))
    }

    func printSuccess(_ message: String) {
        print(colorize("✓ \(message)", .green))
    }

    func printFailure(_ message: String) {
        print(colorize("✗ \(message)", .red))
    }

    func printInfo(_ message: String) {
        print(colorize("ℹ \(message)", .cyan))
    }

    func recordFailure(_ test: String, expected: String, actual: String) {
        testsFailed += 1
        let failure = """
        Test: \(test)
        Expected: \(expected)
        Actual: \(actual)
        """
        failureLog.append(failure)
        printFailure("Test failed")
    }

    func recordSuccess(_ test: String) {
        testsPassed += 1
        printSuccess("Test passed")
    }

    // MARK: - Connection Test

    func testConnection() async -> Bool {
        printTestStart("Connection Test")
        printInfo("Attempting to connect to \(radio.name) on \(port)...")

        do {
            try await rig.connect()
            printSuccess("Connected successfully")

            // Give user time to observe
            try await Task.sleep(for: .seconds(1))

            let confirmed = readYesNo(prompt: "Did the radio respond (no error messages)?")
            if confirmed {
                recordSuccess("Connection")
                return true
            } else {
                let actual = readLine(prompt: "What happened?")
                recordFailure("Connection", expected: "Successful connection", actual: actual)
                return false
            }
        } catch {
            printFailure("Connection failed: \(error)")
            recordFailure("Connection", expected: "Successful connection", actual: error.localizedDescription)
            return false
        }
    }

    // MARK: - Frequency Tests

    func testFrequencyReadWrite() async -> Bool {
        printTestStart("Frequency Read/Write Test")

        // Determine appropriate test frequency based on radio
        let testFrequencies: [(frequency: UInt64, band: String)] = getTestFrequencies()

        // Get VFO architecture for this radio
        let vfoArch = getVFOArchitecture()

        for (frequency, band) in testFrequencies {
            printInfo("Testing \(band) band: \(formatFrequency(frequency))")

            do {
                // Set frequency
                printInfo("Setting \(vfoArch.primaryName) to \(formatFrequency(frequency))...")
                try await rig.setFrequency(frequency, vfo: vfoArch.primaryVFO)
                try await Task.sleep(for: .milliseconds(500))

                printInfo("Check your radio display:")
                printInfo("  \(vfoArch.primaryName) should show: \(formatFrequency(frequency))")

                let setConfirmed = readYesNo(prompt: "Does \(vfoArch.primaryName) show \(formatFrequency(frequency))?")
                if !setConfirmed {
                    let actual = readLine(prompt: "What frequency does \(vfoArch.primaryName) show?")
                    recordFailure("Set Frequency \(band)", expected: formatFrequency(frequency), actual: actual)
                    return false
                }

                // Read frequency back
                printInfo("Reading frequency from \(vfoArch.primaryName)...")
                let readFreq = try await rig.frequency(vfo: vfoArch.primaryVFO, cached: false)
                printInfo("Read frequency: \(formatFrequency(readFreq))")

                if readFreq == frequency {
                    printSuccess("Frequency matches: \(formatFrequency(readFreq))")
                } else {
                    printFailure("Frequency mismatch: Expected \(formatFrequency(frequency)), got \(formatFrequency(readFreq))")
                    recordFailure("Read Frequency \(band)", expected: formatFrequency(frequency), actual: formatFrequency(readFreq))
                    return false
                }

            } catch {
                printFailure("Frequency test failed: \(error)")
                recordFailure("Frequency \(band)", expected: "Successful read/write", actual: error.localizedDescription)
                return false
            }
        }

        recordSuccess("Frequency Read/Write")
        return true
    }

    // MARK: - Mode Tests

    func testModeReadWrite() async -> Bool {
        printTestStart("Mode Read/Write Test")

        let testModes: [(mode: Mode, name: String)] = getTestModes()

        // Get VFO architecture for this radio
        let vfoArch = getVFOArchitecture()

        for (mode, name) in testModes {
            printInfo("Testing mode: \(name)")

            do {
                // Set appropriate frequency for the mode being tested
                let testFreq = getFrequencyForMode(mode)
                if let freq = testFreq {
                    printInfo("Setting frequency to \(Double(freq) / 1_000_000) MHz for \(name) test...")
                    try await rig.setFrequency(freq, vfo: vfoArch.primaryVFO)
                    try await Task.sleep(for: .milliseconds(300))
                }

                // Set mode
                printInfo("Setting \(vfoArch.primaryName) to \(name) mode...")
                try await rig.setMode(mode, vfo: vfoArch.primaryVFO)
                try await Task.sleep(for: .milliseconds(500))

                printInfo("Check your radio display:")
                printInfo("  \(vfoArch.primaryName) mode should show: \(name)")

                let setConfirmed = readYesNo(prompt: "Does \(vfoArch.primaryName) show \(name) mode?")
                if !setConfirmed {
                    let actual = readLine(prompt: "What mode does \(vfoArch.primaryName) show?")
                    recordFailure("Set Mode \(name)", expected: name, actual: actual)
                    return false
                }

                // Read mode back
                printInfo("Reading mode from \(vfoArch.primaryName)...")
                let readMode = try await rig.mode(vfo: vfoArch.primaryVFO, cached: false)
                printInfo("Read mode: \(readMode)")

                if readMode == mode {
                    printSuccess("Mode matches: \(readMode)")
                } else {
                    printFailure("Mode mismatch: Expected \(mode), got \(readMode)")
                    recordFailure("Read Mode \(name)", expected: "\(mode)", actual: "\(readMode)")
                    return false
                }

            } catch {
                printFailure("Mode test failed: \(error)")
                recordFailure("Mode \(name)", expected: "Successful read/write", actual: error.localizedDescription)
                return false
            }
        }

        recordSuccess("Mode Read/Write")
        return true
    }

    // MARK: - PTT Tests

    func testPTT() async -> Bool {
        printTestStart("PTT (Push-To-Talk) Test")

        printInfo(colorize("⚠️  WARNING: This test will key your transmitter!", .yellow))
        printInfo(colorize("⚠️  Ensure antenna is connected or use a dummy load!", .yellow))

        let proceed = readYesNo(prompt: "Ready to proceed with PTT test?")
        if !proceed {
            printInfo("Skipping PTT test")
            return true
        }

        do {
            // Test PTT ON
            printInfo("Activating PTT (transmit)...")
            try await rig.setPTT(true)
            try await Task.sleep(for: .milliseconds(500))

            printInfo("Check your radio:")
            printInfo("  - TX indicator should be lit")
            printInfo("  - You should see 'TX' or 'SEND' on the display")

            let txConfirmed = readYesNo(prompt: "Is the radio transmitting?")
            if !txConfirmed {
                let actual = readLine(prompt: "What is the radio doing?")
                try await rig.setPTT(false) // Safety: turn off PTT
                recordFailure("PTT ON", expected: "Radio transmitting", actual: actual)
                return false
            }

            // Verify PTT state
            printInfo("Reading PTT state...")
            let pttState = try await rig.isPTTEnabled()
            if pttState {
                printSuccess("PTT state is ON")
            } else {
                printFailure("PTT state is OFF (expected ON)")
                try await rig.setPTT(false) // Safety
                recordFailure("PTT State Read", expected: "ON", actual: "OFF")
                return false
            }

            // Test PTT OFF
            printInfo("Deactivating PTT (receive)...")
            try await rig.setPTT(false)
            try await Task.sleep(for: .milliseconds(500))

            printInfo("Check your radio:")
            printInfo("  - TX indicator should be off")
            printInfo("  - Radio should be in receive mode")

            let rxConfirmed = readYesNo(prompt: "Is the radio in receive mode?")
            if !rxConfirmed {
                let actual = readLine(prompt: "What is the radio doing?")
                recordFailure("PTT OFF", expected: "Radio in receive mode", actual: actual)
                return false
            }

            // Verify PTT state OFF
            printInfo("Reading PTT state...")
            let pttStateOff = try await rig.isPTTEnabled()
            if !pttStateOff {
                printSuccess("PTT state is OFF")
            } else {
                printFailure("PTT state is ON (expected OFF)")
                recordFailure("PTT State Read OFF", expected: "OFF", actual: "ON")
                return false
            }

        } catch {
            printFailure("PTT test failed: \(error)")
            // Safety: ensure PTT is off
            try? await rig.setPTT(false)
            recordFailure("PTT", expected: "Successful PTT control", actual: error.localizedDescription)
            return false
        }

        recordSuccess("PTT Control")
        return true
    }

    // MARK: - Power Tests

    func testPower() async -> Bool {
        printTestStart("Power Level Test")

        guard radio.definition.capabilities.powerControl else {
            printInfo("Power control not supported on this radio - skipping")
            return true
        }

        let testPowers = [25, 50, 75, 100]

        for power in testPowers {
            printInfo("Testing power level: \(power)%")

            do {
                // Set power
                printInfo("Setting power to \(power)%...")
                try await rig.setPower(power)
                try await Task.sleep(for: .milliseconds(500))

                printInfo("Check your radio display:")
                printInfo("  Power level should show: \(power)%")
                printInfo("  (May be shown as 'RF PWR' or similar)")

                let setConfirmed = readYesNo(prompt: "Does the radio show \(power)% power?")
                if !setConfirmed {
                    let actual = readLine(prompt: "What power level does the radio show?")
                    recordFailure("Set Power \(power)%", expected: "\(power)%", actual: actual)
                    return false
                }

                // Read power back
                printInfo("Reading power level...")
                let readPower = try await rig.power()
                printInfo("Read power: \(readPower)%")

                // Allow 1% tolerance for rounding
                if abs(readPower - power) <= 1 {
                    printSuccess("Power matches: \(readPower)%")
                } else {
                    printFailure("Power mismatch: Expected \(power)%, got \(readPower)%")
                    recordFailure("Read Power \(power)%", expected: "\(power)%", actual: "\(readPower)%")
                    return false
                }

            } catch {
                printFailure("Power test failed: \(error)")
                recordFailure("Power \(power)%", expected: "Successful read/write", actual: error.localizedDescription)
                return false
            }
        }

        recordSuccess("Power Control")
        return true
    }

    // MARK: - VFO Tests

    func testVFO() async -> Bool {
        printTestStart("VFO Selection Test")

        guard radio.definition.capabilities.hasVFOB else {
            printInfo("VFO B not supported on this radio - skipping")
            return true
        }

        // Get two different test frequencies appropriate for this radio
        let testFreqs = getVFOTestFrequencies()
        guard testFreqs.count >= 2 else {
            printInfo("Not enough bands available for VFO independence test - skipping")
            return true
        }

        let (testFreq1, band1) = testFreqs[0]
        let (testFreq2, band2) = testFreqs[1]

        // Get VFO architecture for this radio
        let vfoArch = getVFOArchitecture()

        do {
            // Set first VFO
            printInfo("Setting \(vfoArch.primaryName) to \(formatFrequency(testFreq1)) (\(band1))...")
            try await rig.setFrequency(testFreq1, vfo: vfoArch.primaryVFO)
            try await Task.sleep(for: .milliseconds(500))

            printInfo("Check your radio: \(vfoArch.primaryName) should show \(formatFrequency(testFreq1))")
            let vfo1Confirmed = readYesNo(prompt: "Does \(vfoArch.primaryName) show \(formatFrequency(testFreq1))?")
            if !vfo1Confirmed {
                let actual = readLine(prompt: "What does \(vfoArch.primaryName) show?")
                recordFailure("\(vfoArch.primaryName) Selection", expected: formatFrequency(testFreq1), actual: actual)
                return false
            }

            // Set second VFO
            printInfo("Setting \(vfoArch.secondaryName) to \(formatFrequency(testFreq2)) (\(band2))...")
            try await rig.setFrequency(testFreq2, vfo: vfoArch.secondaryVFO)
            try await Task.sleep(for: .milliseconds(500))

            printInfo("Check your radio: \(vfoArch.secondaryName) should show \(formatFrequency(testFreq2))")
            let vfo2Confirmed = readYesNo(prompt: "Does \(vfoArch.secondaryName) show \(formatFrequency(testFreq2))?")
            if !vfo2Confirmed {
                let actual = readLine(prompt: "What does \(vfoArch.secondaryName) show?")
                recordFailure("\(vfoArch.secondaryName) Selection", expected: formatFrequency(testFreq2), actual: actual)
                return false
            }

            // Read back both VFOs
            printInfo("Reading \(vfoArch.primaryName) frequency...")
            let readFreq1 = try await rig.frequency(vfo: vfoArch.primaryVFO, cached: false)
            printInfo("\(vfoArch.primaryName): \(formatFrequency(readFreq1))")

            printInfo("Reading \(vfoArch.secondaryName) frequency...")
            let readFreq2 = try await rig.frequency(vfo: vfoArch.secondaryVFO, cached: false)
            printInfo("\(vfoArch.secondaryName): \(formatFrequency(readFreq2))")

            if readFreq1 == testFreq1 && readFreq2 == testFreq2 {
                printSuccess("Both VFOs match expected frequencies")
            } else {
                printFailure("VFO mismatch detected")
                recordFailure("VFO Read Back",
                            expected: "\(vfoArch.primaryName)=\(formatFrequency(testFreq1)), \(vfoArch.secondaryName)=\(formatFrequency(testFreq2))",
                            actual: "\(vfoArch.primaryName)=\(formatFrequency(readFreq1)), \(vfoArch.secondaryName)=\(formatFrequency(readFreq2))")
                return false
            }

        } catch {
            printFailure("VFO test failed: \(error)")
            recordFailure("VFO", expected: "Successful VFO control", actual: error.localizedDescription)
            return false
        }

        recordSuccess("VFO Selection")
        return true
    }

    // MARK: - Split Operation Test

    func testSplit() async -> Bool {
        printTestStart("Split Operation Test")

        guard radio.definition.capabilities.hasSplit else {
            printInfo("Split operation not supported on this radio - skipping")
            return true
        }

        do {
            // Enable split
            printInfo("Enabling split operation...")
            try await rig.setSplit(true)
            try await Task.sleep(for: .milliseconds(500))

            printInfo("Check your radio:")
            printInfo("  - Split indicator should be lit")
            printInfo("  - Display may show 'SPLIT' or 'SPL'")

            let splitOnConfirmed = readYesNo(prompt: "Is split mode enabled on the radio?")
            if !splitOnConfirmed {
                let actual = readLine(prompt: "What does the radio show?")
                recordFailure("Split ON", expected: "Split enabled", actual: actual)
                return false
            }

            // Read split state
            printInfo("Reading split state...")
            let splitState = try await rig.isSplitEnabled()
            if splitState {
                printSuccess("Split state is ON")
            } else {
                printFailure("Split state is OFF (expected ON)")
                recordFailure("Split State Read", expected: "ON", actual: "OFF")
                return false
            }

            // Disable split
            printInfo("Disabling split operation...")
            try await rig.setSplit(false)
            try await Task.sleep(for: .milliseconds(500))

            printInfo("Check your radio:")
            printInfo("  - Split indicator should be off")

            let splitOffConfirmed = readYesNo(prompt: "Is split mode disabled on the radio?")
            if !splitOffConfirmed {
                let actual = readLine(prompt: "What does the radio show?")
                recordFailure("Split OFF", expected: "Split disabled", actual: actual)
                return false
            }

            // Read split state OFF
            printInfo("Reading split state...")
            let splitStateOff = try await rig.isSplitEnabled()
            if !splitStateOff {
                printSuccess("Split state is OFF")
            } else {
                printFailure("Split state is ON (expected OFF)")
                recordFailure("Split State Read OFF", expected: "OFF", actual: "ON")
                return false
            }

        } catch {
            printFailure("Split test failed: \(error)")
            recordFailure("Split", expected: "Successful split control", actual: error.localizedDescription)
            return false
        }

        recordSuccess("Split Operation")
        return true
    }

    // MARK: - Signal Strength Test

    func testSignalStrength() async -> Bool {
        printTestStart("Signal Strength (S-Meter) Test")

        guard radio.definition.capabilities.supportsSignalStrength else {
            printInfo("Signal strength reading not supported on this radio - skipping")
            return true
        }

        printInfo("This test will read the S-meter value from your radio")
        printInfo("Tune to a frequency with a signal (or leave on an empty frequency)")

        let proceed = readYesNo(prompt: "Ready to test S-meter?")
        if !proceed {
            printInfo("Skipping S-meter test")
            return true
        }

        do {
            printInfo("Reading signal strength...")
            let signal = try await rig.signalStrength(cached: false)

            printInfo("S-Meter reading:")
            printInfo("  S-Units: S\(signal.sUnits)")
            if signal.overS9 > 0 {
                printInfo("  Over S9: +\(signal.overS9) dB")
            }
            printInfo("  Raw value: \(signal.raw)")

            printInfo("Compare this with your radio's S-meter display")

            let confirmed = readYesNo(prompt: "Does this reading match your radio's S-meter?")
            if confirmed {
                printSuccess("S-meter reading verified")
                recordSuccess("Signal Strength")
                return true
            } else {
                let actual = readLine(prompt: "What does your radio's S-meter show?")
                recordFailure("Signal Strength", expected: "S\(signal.sUnits)", actual: actual)
                return false
            }

        } catch {
            printFailure("Signal strength test failed: \(error)")
            recordFailure("Signal Strength", expected: "Successful read", actual: error.localizedDescription)
            return false
        }
    }

    // MARK: - Test Suite Runner

    func runAllTests() async {
        printHeader("Icom CI-V Comprehensive Test Suite")
        print(colorize("Radio: \(radio.name) - \(radio.description)", .bold))
        print(colorize("Port: \(port) @ \(baudRate) baud", .bold))

        var continueTests = true

        // Connection test
        continueTests = await testConnection()

        // Frequency test
        if continueTests {
            continueTests = await testFrequencyReadWrite()
        }

        // Mode test
        if continueTests {
            continueTests = await testModeReadWrite()
        }

        // VFO test
        if continueTests {
            continueTests = await testVFO()
        }

        // Split test
        if continueTests {
            continueTests = await testSplit()
        }

        // Power test
        if continueTests {
            continueTests = await testPower()
        }

        // PTT test
        if continueTests {
            continueTests = await testPTT()
        }

        // Signal strength test
        if continueTests {
            _ = await testSignalStrength()
        }

        // Disconnect
        await rig.disconnect()

        // Print results
        printResults()
    }

    func printResults() {
        printHeader("Test Results")

        let total = testsPassed + testsFailed
        let passRate = total > 0 ? (Double(testsPassed) / Double(total)) * 100 : 0

        print("\nTotal Tests: \(total)")
        print(colorize("Passed: \(testsPassed)", .green))
        if testsFailed > 0 {
            print(colorize("Failed: \(testsFailed)", .red))
        }
        print(colorize(String(format: "Pass Rate: %.1f%%", passRate), passRate == 100 ? .green : .yellow))

        if !failureLog.isEmpty {
            printHeader("Failure Details")
            for (index, failure) in failureLog.enumerated() {
                print("\n" + colorize("Failure #\(index + 1):", .red))
                print(failure)
            }

            printHeader("Troubleshooting Suggestions")
            print("""
            If tests failed, try the following:

            1. Verify cable connection between computer and radio
            2. Check that the correct serial port was selected
            3. Verify baud rate matches radio's CI-V settings
            4. Ensure radio's CI-V transceive is OFF (some radios)
            5. Check CI-V address matches radio's configuration
            6. Try power cycling the radio
            7. Verify no other software is using the serial port
            8. Check radio firmware version (may need update)
            """)
        } else {
            print("\n" + colorize("🎉 All tests passed! Your radio is working perfectly.", .green))
        }
    }

    // MARK: - Helper Methods

    /// VFO architecture information for this radio
    struct VFOArchitecture {
        let primaryVFO: VFO
        let secondaryVFO: VFO
        let primaryName: String
        let secondaryName: String

        /// Detect VFO architecture from radio capabilities and name
        static func detect(for radio: TestRadio) -> VFOArchitecture {
            // Main/Sub radios: IC-7600, IC-7610, IC-9700, IC-9100
            let usesMainSub = ["IC-7600", "IC-7610", "IC-9700", "IC-9100"].contains(radio.name)

            if usesMainSub {
                return VFOArchitecture(
                    primaryVFO: .main,
                    secondaryVFO: .sub,
                    primaryName: "Main",
                    secondaryName: "Sub"
                )
            } else {
                return VFOArchitecture(
                    primaryVFO: .a,
                    secondaryVFO: .b,
                    primaryName: "VFO A",
                    secondaryName: "VFO B"
                )
            }
        }
    }

    /// Get VFO architecture for this radio
    func getVFOArchitecture() -> VFOArchitecture {
        return VFOArchitecture.detect(for: radio)
    }

    func getTestFrequencies() -> [(frequency: UInt64, band: String)] {
        let caps = radio.definition.capabilities
        var frequencies: [(UInt64, String)] = []

        // Use detailed frequency ranges if available for better accuracy
        if !caps.detailedFrequencyRanges.isEmpty {
            // Pick the first transmittable band from each region
            var foundHF = false
            var foundVHF = false
            var foundUHF = false
            var found23cm = false

            for range in caps.detailedFrequencyRanges where range.canTransmit {
                // HF bands (< 30 MHz) - prefer 20m for HF
                if !foundHF && range.min < 30_000_000 {
                    if let bandName = range.bandName {
                        // Use specific well-known frequencies instead of mid-range
                        let testFreq: UInt64
                        if bandName == "20m" {
                            testFreq = 14_200_000  // 14.200 MHz (20m SSB)
                        } else if bandName == "40m" {
                            testFreq = 7_100_000   // 7.100 MHz (40m SSB)
                        } else if bandName == "160m" {
                            testFreq = 1_900_000   // 1.900 MHz (160m SSB)
                        } else {
                            // For other bands, use a frequency well within the range
                            testFreq = range.min + (range.max - range.min) / 3
                        }
                        frequencies.append((testFreq, bandName))
                        foundHF = true
                    }
                }
                // VHF (144-148 MHz)
                else if !foundVHF && range.min >= 144_000_000 && range.max <= 148_000_000 {
                    frequencies.append((145_000_000, range.bandName ?? "2m"))
                    foundVHF = true
                }
                // UHF (430-450 MHz)
                else if !foundUHF && range.min >= 430_000_000 && range.max <= 450_000_000 {
                    frequencies.append((435_000_000, range.bandName ?? "70cm"))
                    foundUHF = true
                }
                // 1.2 GHz (1240-1300 MHz)
                else if !found23cm && range.min >= 1_240_000_000 && range.max <= 1_300_000_000 {
                    frequencies.append((1_270_000_000, range.bandName ?? "23cm"))
                    found23cm = true
                }
            }

            if frequencies.isEmpty {
                // No transmit bands found, use first receive-only range
                if let firstRange = caps.detailedFrequencyRanges.first {
                    let midFreq = firstRange.min + (firstRange.max - firstRange.min) / 2
                    frequencies.append((midFreq, firstRange.bandName ?? "Receive"))
                }
            }

            return frequencies
        }

        // Fall back to frequency range if detailed ranges not available
        guard let freqRange = caps.frequencyRange else {
            return [(14_200_000, "20m")]  // Default
        }

        // HF bands (if supported)
        if freqRange.min <= 14_000_000 && freqRange.max >= 14_350_000 {
            frequencies.append((14_200_000, "20m"))
        }
        if freqRange.min <= 7_000_000 && freqRange.max >= 7_300_000 {
            frequencies.append((7_100_000, "40m"))
        }

        // VHF (if supported)
        if freqRange.min <= 144_000_000 && freqRange.max >= 148_000_000 {
            frequencies.append((145_000_000, "2m"))
        }

        // UHF (if supported)
        if freqRange.min <= 430_000_000 && freqRange.max >= 450_000_000 {
            frequencies.append((435_000_000, "70cm"))
        }

        // 1.2 GHz (if supported)
        if freqRange.min <= 1_240_000_000 && freqRange.max >= 1_300_000_000 {
            frequencies.append((1_270_000_000, "23cm"))
        }

        // If no standard bands found, use a frequency in the middle of the range
        if frequencies.isEmpty {
            let midFreq = (freqRange.min + freqRange.max) / 2
            frequencies.append((midFreq, "Mid-Range"))
        }

        return frequencies
    }

    func getVFOTestFrequencies() -> [(frequency: UInt64, band: String)] {
        // Get all available test frequencies
        let allFreqs = getTestFrequencies()

        // For VFO independence testing, we want TWO different frequencies
        // Prefer widely separated frequencies to make the test more obvious
        if allFreqs.count >= 2 {
            return Array(allFreqs.prefix(2))
        } else if allFreqs.count == 1 {
            // Only one band available - use two different frequencies in same band
            let (freq, band) = allFreqs[0]
            let offset: UInt64 = 100_000  // 100 kHz offset
            return [(freq, band), (freq + offset, band)]
        } else {
            return []
        }
    }

    func getFrequencyForMode(_ mode: Mode) -> UInt64? {
        let caps = radio.definition.capabilities

        guard let freqRange = caps.frequencyRange else {
            return nil
        }

        // Find an appropriate frequency for the mode
        switch mode {
        case .lsb:
            // Use 160m, 80m, or 40m (lower HF bands use LSB)
            if freqRange.min <= 1_900_000 && freqRange.max >= 1_900_000 {
                return 1_900_000  // 160m
            } else if freqRange.min <= 3_750_000 && freqRange.max >= 3_750_000 {
                return 3_750_000  // 80m
            } else if freqRange.min <= 7_100_000 && freqRange.max >= 7_100_000 {
                return 7_100_000  // 40m
            }
        case .usb:
            // Use 20m, 2m, or 70cm (upper HF and VHF/UHF use USB)
            if freqRange.min <= 14_200_000 && freqRange.max >= 14_200_000 {
                return 14_200_000  // 20m
            } else if freqRange.min <= 145_000_000 && freqRange.max >= 145_000_000 {
                return 145_000_000  // 2m
            } else if freqRange.min <= 435_000_000 && freqRange.max >= 435_000_000 {
                return 435_000_000  // 70cm
            }
        case .fm:
            // FM is typically VHF/UHF
            if freqRange.min <= 145_000_000 && freqRange.max >= 145_000_000 {
                return 145_000_000  // 2m
            } else if freqRange.min <= 435_000_000 && freqRange.max >= 435_000_000 {
                return 435_000_000  // 70cm
            }
        case .cw:
            // CW works on most bands, use 20m if available, else 2m
            if freqRange.min <= 14_050_000 && freqRange.max >= 14_050_000 {
                return 14_050_000  // 20m CW
            } else if freqRange.min <= 145_000_000 && freqRange.max >= 145_000_000 {
                return 145_000_000  // 2m
            }
        default:
            // For other modes, don't change frequency
            return nil
        }

        return nil  // No suitable frequency found
    }

    func getTestModes() -> [(mode: Mode, name: String)] {
        let caps = radio.definition.capabilities
        var modes: [(Mode, String)] = []

        // Always test USB and LSB if supported
        if caps.supportedModes.contains(.usb) {
            modes.append((.usb, "USB"))
        }
        if caps.supportedModes.contains(.lsb) {
            modes.append((.lsb, "LSB"))
        }

        // Add FM if supported
        if caps.supportedModes.contains(.fm) {
            modes.append((.fm, "FM"))
        }

        // Add CW if supported
        if caps.supportedModes.contains(.cw) {
            modes.append((.cw, "CW"))
        }

        return modes
    }

    func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.3f MHz", mhz)
    }
}

// MARK: - Serial Port Discovery

func listSerialPorts() -> [String] {
    let fileManager = FileManager.default
    let devPath = "/dev"

    guard let contents = try? fileManager.contentsOfDirectory(atPath: devPath) else {
        return []
    }

    // Filter for cu.* devices (macOS/BSD style) and ttyUSB/ttyACM (Linux style)
    let ports = contents.filter {
        $0.hasPrefix("cu.") ||
        $0.hasPrefix("ttyUSB") ||
        $0.hasPrefix("ttyACM")
    }.sorted().map { "/dev/\($0)" }

    return ports
}

// MARK: - Main Program

@main
struct IcomInteractiveTester {
    static func main() async {
        print(colorize("""
        ╔════════════════════════════════════════════════════════════════════╗
        ║                                                                    ║
        ║          Icom CI-V Comprehensive Interactive Test Suite           ║
        ║                                                                    ║
        ╚════════════════════════════════════════════════════════════════════╝
        """, .bold))

        print("\nThis test suite will verify complete CI-V functionality for your Icom radio.")
        print("The tests will guide you through each step and ask for confirmation.\n")

        // Select radio
        print(colorize("Available Radios:", .bold))
        for (index, radio) in availableRadios.enumerated() {
            print("\(index + 1). \(radio.name) - \(radio.description)")
        }

        guard let radioChoice = readInt(prompt: "\nSelect radio (1-\(availableRadios.count)):", min: 1, max: availableRadios.count) else {
            print(colorize("Invalid selection", .red))
            return
        }

        let selectedRadio = availableRadios[radioChoice - 1]
        print(colorize("\nSelected: \(selectedRadio.name)", .green))

        // List serial ports
        print("\n" + colorize("Available Serial Ports:", .bold))
        let ports = listSerialPorts()

        if ports.isEmpty {
            print(colorize("No serial ports found!", .red))
            print("Please check your USB connections and try again.")
            return
        }

        for (index, port) in ports.enumerated() {
            print("\(index + 1). \(port)")
        }

        guard let portChoice = readInt(prompt: "\nSelect port (1-\(ports.count)):", min: 1, max: ports.count) else {
            print(colorize("Invalid selection", .red))
            return
        }

        let selectedPort = ports[portChoice - 1]
        print(colorize("\nSelected: \(selectedPort)", .green))

        // Baud rate
        let defaultBaud = selectedRadio.definition.defaultBaudRate
        print("\nDefault baud rate for \(selectedRadio.name): \(defaultBaud)")
        let useDefault = readYesNo(prompt: "Use default baud rate?")

        let baudRate: Int
        if useDefault {
            baudRate = defaultBaud
        } else {
            print("Common baud rates: 4800, 9600, 19200, 38400, 57600, 115200")
            guard let customBaud = readInt(prompt: "Enter baud rate:", min: 1200, max: 115200) else {
                print(colorize("Invalid baud rate", .red))
                return
            }
            baudRate = customBaud
        }

        print(colorize("\nBaud rate: \(baudRate)", .green))

        // Create test suite
        let testSuite = IcomTestSuite(radio: selectedRadio, port: selectedPort, baudRate: baudRate)

        // Final confirmation
        print("\n" + colorize("Test Configuration:", .bold))
        print("  Radio: \(selectedRadio.name)")
        print("  Port: \(selectedPort)")
        print("  Baud Rate: \(baudRate)")
        print("\nMake sure your radio is:")
        print("  ✓ Powered on")
        print("  ✓ Connected via CI-V cable")
        if let addr = selectedRadio.definition.civAddress {
            print("  ✓ CI-V address matches (0x\(String(format: "%02X", addr)))")
        }
        print("  ✓ CI-V baud rate matches (\(baudRate))")
        print("  ✓ CI-V transceive is OFF (if applicable)")

        let proceed = readYesNo(prompt: "\nReady to start testing?")
        if !proceed {
            print(colorize("\nTest cancelled", .yellow))
            return
        }

        // Run tests
        await testSuite.runAllTests()

        print("\n" + colorize("Test suite complete!", .bold))
    }
}
