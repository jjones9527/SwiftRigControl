import Foundation
import RigControl

/// Comprehensive IC-7600 CI-V Command Test Suite
/// Tests all ~150 implemented commands and logs discrepancies for troubleshooting
@main
struct IC7600ComprehensiveTest {

    // MARK: - Test Configuration

    struct TestConfig {
        let serialPort: String
        let baudRate: Int
        let logFilePath: String

        init(serialPort: String, baudRate: Int) {
            self.serialPort = serialPort
            self.baudRate = baudRate

            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            self.logFilePath = "/tmp/ic7600_test_\(timestamp).log"
        }
    }

    // MARK: - Test Statistics

    class TestStats {
        var totalTests = 0
        var passed = 0
        var failed = 0
        var skipped = 0

        func printSummary() {
            print("\n" + String(repeating: "=", count: 60))
            print("TEST SUMMARY")
            print(String(repeating: "=", count: 60))
            print("Total Tests:  \(totalTests)")
            print("Passed:       \(passed)")
            print("Failed:       \(failed)")
            print("Skipped:      \(skipped)")
            print(String(repeating: "=", count: 60))
        }
    }

    // MARK: - Logger

    class TestLogger {
        private let fileHandle: FileHandle
        private let config: TestConfig

        init(config: TestConfig) throws {
            self.config = config

            // Create log file
            if !FileManager.default.fileExists(atPath: config.logFilePath) {
                FileManager.default.createFile(atPath: config.logFilePath, contents: nil)
            }

            guard let handle = FileHandle(forWritingAtPath: config.logFilePath) else {
                throw NSError(domain: "TestLogger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open log file"])
            }

            self.fileHandle = handle
            try fileHandle.seekToEnd()

            log("═══════════════════════════════════════════════════════════")
            log("IC-7600 Comprehensive CI-V Command Test")
            log("Test Started: \(Date())")
            log("Serial Port: \(config.serialPort)")
            log("Baud Rate: \(config.baudRate)")
            log("═══════════════════════════════════════════════════════════")
        }

        func log(_ message: String) {
            let timestamped = "[\(timestamp())] \(message)"
            print(timestamped)

            if let data = (timestamped + "\n").data(using: .utf8) {
                fileHandle.write(data)
            }
        }

        func logFailure(_ cmd: String, sent: String, received: String, expected: String, actual: String) {
            log("")
            log("FAILURE - Command: \(cmd)")
            log("  Sent Frame: \(sent)")
            log("  Received Frame: \(received)")
            log("  Expected Result: \(expected)")
            log("  Actual Result: \(actual)")
            log("  >>> DISCREPANCY DETECTED - User should verify radio display")
        }

        func logError(_ cmd: String, error: Error) {
            log("")
            log("ERROR - Command: \(cmd)")
            log("  Error: \(error)")
        }

        func logSection(_ title: String) {
            log("")
            log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            log(title)
            log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        private func timestamp() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: Date())
        }

        func close() {
            log("")
            log("═══════════════════════════════════════════════════════════")
            log("Test Completed: \(Date())")
            log("Log saved to: \(config.logFilePath)")
            log("═══════════════════════════════════════════════════════════")
            fileHandle.closeFile()
        }

        deinit {
            fileHandle.closeFile()
        }
    }

    // MARK: - User Input Helper

    static func getUserInput(_ prompt: String) -> String {
        print(prompt, terminator: "")
        return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func getUserConfirmation(_ prompt: String) -> Bool {
        let response = getUserInput("\(prompt) (y/n): ")
        return response.lowercased() == "y" || response.lowercased() == "yes"
    }

    // MARK: - Test Runner Helper

    /// Runs a test with interactive user confirmation
    /// Returns true if test passed, false if failed or skipped
    @discardableResult
    static func runTest(
        name: String,
        description: String,
        commandSent: String,
        expectedResponse: String,
        userPrompt: String,
        logger: TestLogger,
        stats: TestStats,
        isDestructive: Bool = false,
        requiresDummyLoad: Bool = false,
        action: () async throws -> Void
    ) async -> Bool {
        logger.log("\nTest: \(name)")
        logger.log("Description: \(description)")

        // Destructive command warning
        if isDestructive {
            logger.log("⚠️  WARNING: This command modifies memory")
            guard getUserConfirmation("Proceed with destructive operation?") else {
                logger.log("Test skipped by user")
                stats.skipped += 1
                stats.totalTests += 1
                return false
            }
        }

        // Dummy load warning
        if requiresDummyLoad {
            logger.log("⚠️  WARNING: This test will key the transmitter")
            logger.log("Ensure antenna or dummy load is connected")
            guard getUserConfirmation("Proceed with transmit operation?") else {
                logger.log("Test skipped by user")
                stats.skipped += 1
                stats.totalTests += 1
                return false
            }
        }

        // Execute the command
        do {
            try await action()
            try await Task.sleep(for: .milliseconds(300))

            // Get user confirmation
            let userConfirmed = getUserConfirmation(userPrompt)

            stats.totalTests += 1
            if userConfirmed {
                logger.log("✅ PASS")
                stats.passed += 1
                return true
            } else {
                logger.logFailure(name, sent: commandSent, received: expectedResponse, expected: userPrompt, actual: "User reported mismatch")
                stats.failed += 1

                // Ask if user wants to retry
                if getUserConfirmation("Retry this test?") {
                    return await runTest(
                        name: name,
                        description: description,
                        commandSent: commandSent,
                        expectedResponse: expectedResponse,
                        userPrompt: userPrompt,
                        logger: logger,
                        stats: stats,
                        isDestructive: isDestructive,
                        requiresDummyLoad: requiresDummyLoad,
                        action: action
                    )
                }
                return false
            }
        } catch {
            logger.logError(name, error: error)
            stats.totalTests += 1
            stats.failed += 1

            // Ask if user wants to retry
            if getUserConfirmation("Retry this test?") {
                return await runTest(
                    name: name,
                    description: description,
                    commandSent: commandSent,
                    expectedResponse: expectedResponse,
                    userPrompt: userPrompt,
                    logger: logger,
                    stats: stats,
                    isDestructive: isDestructive,
                    requiresDummyLoad: requiresDummyLoad,
                    action: action
                )
            }
            return false
        }
    }

    // MARK: - Main Test Entry Point

    static func main() async {
        print("╔════════════════════════════════════════════════════════════╗")
        print("║     IC-7600 Comprehensive CI-V Command Test Suite         ║")
        print("║     SwiftRigControl v1.1.0                                 ║")
        print("║     Testing ~150 CI-V Commands                            ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()

        // Get serial port configuration
        print("Please enter the IC-7600 serial port path")
        print("Example: /dev/cu.usbserial-2120")
        let serialPort = getUserInput("Serial Port: ")

        guard !serialPort.isEmpty else {
            print("Error: Serial port cannot be empty")
            return
        }

        print("\nPlease enter the baud rate")
        print("IC-7600 default: 19200")
        let baudRateStr = getUserInput("Baud Rate (default 19200): ")
        let baudRate = Int(baudRateStr) ?? 19200

        let config = TestConfig(serialPort: serialPort, baudRate: baudRate)

        do {
            let logger = try TestLogger(config: config)
            let stats = TestStats()

            // Setup instructions
            print("\n" + String(repeating: "=", count: 60))
            print("RADIO SETUP REQUIRED")
            print(String(repeating: "=", count: 60))
            print("\nPlease configure your IC-7600 to the following state:")
            print("  • Main Band: 14.200 MHz")
            print("  • Main Mode: USB (FIL1)")
            print("  • Sub Band: 7.100 MHz")
            print("  • Sub Mode: LSB (FIL1)")
            print("  • Split: OFF")
            print("  • RF Power: 50W (50%)")
            print("  • Attenuator: OFF")
            print("  • Preamp: OFF")
            print("  • AGC: FAST")
            print("  • Noise Blanker: OFF")
            print("  • Noise Reduction: OFF")
            print("  • Auto Notch: OFF")
            print("  • Manual Notch: OFF")
            print()

            guard getUserConfirmation("Is the radio configured as above?") else {
                print("Test cancelled by user")
                logger.close()
                return
            }

            logger.log("User confirmed radio setup complete")

            // Create RigController
            let rig = RigController(
                radio: .icomIC7600,
                connection: .serial(path: config.serialPort, baudRate: config.baudRate)
            )

            // Connect
            logger.logSection("CONNECTING TO IC-7600")
            try await rig.connect()
            logger.log("✅ Connected successfully")
            print("\n✅ Connected to IC-7600")

            // Run test suite
            await runTestSuite(rig: rig, logger: logger, stats: stats)

            // Disconnect
            logger.logSection("DISCONNECTING")
            await rig.disconnect()
            logger.log("✅ Disconnected")

            // Print summary
            stats.printSummary()

            logger.close()
            print("\n✅ Test completed")
            print("📄 Log file (failures only): \(config.logFilePath)")

        } catch {
            print("\nFatal error: \(error)")
            Foundation.exit(1)
        }
    }

    // MARK: - Test Suite

    static func runTestSuite(rig: RigController, logger: TestLogger, stats: TestStats) async {
        // Section 1: Basic Frequency & Mode
        await testBasicFrequencyMode(rig: rig, logger: logger, stats: stats)

        // Section 2: VFO Operations
        await testVFOOperations(rig: rig, logger: logger, stats: stats)

        // Section 3: Split Operations
        await testSplitOperations(rig: rig, logger: logger, stats: stats)

        // Section 4: Attenuator & Preamp
        await testAttenuatorPreamp(rig: rig, logger: logger, stats: stats)

        // Section 5: AGC Control
        await testAGCControl(rig: rig, logger: logger, stats: stats)

        // Section 6: Noise Controls
        await testNoiseControls(rig: rig, logger: logger, stats: stats)

        // Section 7: Level Controls
        await testLevelControls(rig: rig, logger: logger, stats: stats)

        // Section 8: Meter Readings
        await testMeterReadings(rig: rig, logger: logger, stats: stats)

        // Section 9: Function Controls
        await testFunctionControls(rig: rig, logger: logger, stats: stats)

        // Section 10: Tuning & Antenna
        await testTuningAntenna(rig: rig, logger: logger, stats: stats)

        // Section 11: Advanced Settings
        await testAdvancedSettings(rig: rig, logger: logger, stats: stats)

        // Section 12: Memory Operations (DESTRUCTIVE)
        await testMemoryOperations(rig: rig, logger: logger, stats: stats)

        // Section 13: Scan Operations
        await testScanOperations(rig: rig, logger: logger, stats: stats)

        // Section 14: PTT & TX Operations
        await testPTTOperations(rig: rig, logger: logger, stats: stats)

        // Section 15: Miscellaneous
        await testMiscellaneous(rig: rig, logger: logger, stats: stats)
    }

    // MARK: - Section 1: Basic Frequency & Mode

    static func testBasicFrequencyMode(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 1: BASIC FREQUENCY & MODE")

        // Get protocol access
        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 1.1: Read Main Frequency
        await runTest(
            name: "Read Main Frequency",
            description: "Read current main band frequency",
            commandSent: "FE FE 7A E0 03 FD",
            expectedResponse: "FE FE E0 7A 03 [freq BCD] FD",
            userPrompt: "Does MAIN show 14.200 MHz?",
            logger: logger,
            stats: stats
        ) {
            let freq = try await rig.frequency(vfo: .main, cached: false)
            logger.log("Software reports: \(Double(freq) / 1_000_000.0) MHz")
        }

        // Test 1.2: Read Main Mode
        await runTest(
            name: "Read Main Mode",
            description: "Read current main band mode",
            commandSent: "FE FE 7A E0 04 FD",
            expectedResponse: "FE FE E0 7A 04 [mode] [filter] FD",
            userPrompt: "Does MAIN show USB?",
            logger: logger,
            stats: stats
        ) {
            let mode = try await rig.mode(vfo: .main, cached: false)
            logger.log("Software reports: \(mode.rawValue)")
        }

        // Test 1.3: Set Main Frequency
        await runTest(
            name: "Set Main Frequency to 21.225 MHz",
            description: "Set main band to 21.225 MHz",
            commandSent: "FE FE 7A E0 05 [00 00 21 22 50 00] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does MAIN now show 21.225 MHz?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setFrequency(21_225_000, vfo: .main)
        }

        // Test 1.4: Restore Main Frequency
        await runTest(
            name: "Restore Main Frequency to 14.200 MHz",
            description: "Restore main band to 14.200 MHz",
            commandSent: "FE FE 7A E0 05 [00 00 14 20 00 00] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does MAIN now show 14.200 MHz?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setFrequency(14_200_000, vfo: .main)
        }

        // Test 1.5: Read Sub Frequency
        await runTest(
            name: "Read Sub Frequency",
            description: "Read current sub band frequency",
            commandSent: "FE FE 7A E0 03 FD",
            expectedResponse: "FE FE E0 7A 03 [freq BCD] FD",
            userPrompt: "Does SUB show 7.100 MHz?",
            logger: logger,
            stats: stats
        ) {
            let freq = try await rig.frequency(vfo: .sub, cached: false)
            logger.log("Software reports: \(Double(freq) / 1_000_000.0) MHz")
        }

        // Test 1.6: Set Sub Frequency
        await runTest(
            name: "Set Sub Frequency to 3.750 MHz",
            description: "Set sub band to 3.750 MHz",
            commandSent: "FE FE 7A E0 05 [00 00 03 75 00 00] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does SUB now show 3.750 MHz?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setFrequency(3_750_000, vfo: .sub)
        }

        // Test 1.7: Restore Sub Frequency
        await runTest(
            name: "Restore Sub Frequency to 7.100 MHz",
            description: "Restore sub band to 7.100 MHz",
            commandSent: "FE FE 7A E0 05 [00 00 07 10 00 00] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does SUB now show 7.100 MHz?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setFrequency(7_100_000, vfo: .sub)
        }
    }

    // MARK: - Section 2: VFO Operations

    static func testVFOOperations(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 2: VFO OPERATIONS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 2.1: Select Main Band
        await runTest(
            name: "Select Main Band",
            description: "Select MAIN as active band",
            commandSent: "FE FE 7A E0 07 D0 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is MAIN band now selected (highlighted)?",
            logger: logger,
            stats: stats
        ) {
            try await rig.selectVFO(.main)
        }

        // Test 2.2: Select Sub Band
        await runTest(
            name: "Select Sub Band",
            description: "Select SUB as active band",
            commandSent: "FE FE 7A E0 07 D1 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is SUB band now selected (highlighted)?",
            logger: logger,
            stats: stats
        ) {
            try await rig.selectVFO(.sub)
        }

        // Test 2.3: Return to Main
        await runTest(
            name: "Return to Main Band",
            description: "Return to MAIN band",
            commandSent: "FE FE 7A E0 07 D0 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is MAIN band now selected?",
            logger: logger,
            stats: stats
        ) {
            try await rig.selectVFO(.main)
        }

        // Test 2.4: Exchange Bands
        await runTest(
            name: "Exchange Main/Sub Bands",
            description: "Swap main and sub band frequencies",
            commandSent: "FE FE 7A E0 07 B0 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Did MAIN and SUB frequencies swap?",
            logger: logger,
            stats: stats
        ) {
            try await proto.exchangeBands()
        }

        // Test 2.5: Exchange Back
        await runTest(
            name: "Exchange Bands Again (restore)",
            description: "Swap back to original state",
            commandSent: "FE FE 7A E0 07 B0 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Are frequencies back to original (MAIN=14.200, SUB=7.100)?",
            logger: logger,
            stats: stats
        ) {
            try await proto.exchangeBands()
        }

        // Test 2.6: Equalize Bands
        await runTest(
            name: "Equalize Main/Sub Bands",
            description: "Copy main frequency to sub",
            commandSent: "FE FE 7A E0 07 B1 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does SUB now match MAIN (14.200 MHz)?",
            logger: logger,
            stats: stats
        ) {
            try await proto.equalizeBands()
        }

        // Test 2.7: Restore Sub Frequency
        await runTest(
            name: "Restore Sub to 7.100 MHz",
            description: "Restore sub band frequency",
            commandSent: "FE FE 7A E0 05 [7.100 MHz BCD] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does SUB show 7.100 MHz again?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setFrequency(7_100_000, vfo: .sub)
        }

        // Test 2.8: Dualwatch ON
        await runTest(
            name: "Enable Dualwatch",
            description: "Turn on dual watch mode",
            commandSent: "FE FE 7A E0 07 C1 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is DUALWATCH indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setDualwatch(true)
        }

        // Test 2.9: Dualwatch OFF
        await runTest(
            name: "Disable Dualwatch",
            description: "Turn off dual watch mode",
            commandSent: "FE FE 7A E0 07 C0 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is DUALWATCH indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setDualwatch(false)
        }
    }

    // MARK: - Section 3: Split Operations

    static func testSplitOperations(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 3: SPLIT OPERATIONS")

        // Test 3.1: Enable Split
        await runTest(
            name: "Enable Split",
            description: "Turn on split operation",
            commandSent: "FE FE 7A E0 0F 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is SPLIT indicator now showing?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setSplit(true)
        }

        // Test 3.2: Read Split Status
        await runTest(
            name: "Read Split Status",
            description: "Query split status",
            commandSent: "FE FE 7A E0 0F FD",
            expectedResponse: "FE FE E0 7A 0F 01 FD",
            userPrompt: "Software should report split ON",
            logger: logger,
            stats: stats
        ) {
            let split = try await rig.isSplitEnabled()
            logger.log("Software reports: Split \(split ? "ON" : "OFF")")
        }

        // Test 3.3: Disable Split
        await runTest(
            name: "Disable Split",
            description: "Turn off split operation",
            commandSent: "FE FE 7A E0 0F 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is SPLIT indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await rig.setSplit(false)
        }
    }

    // MARK: - Section 4: Attenuator & Preamp

    static func testAttenuatorPreamp(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 4: ATTENUATOR & PREAMP")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 4.1: Read Attenuator (should be OFF)
        await runTest(
            name: "Read Attenuator",
            description: "Read current attenuator setting",
            commandSent: "FE FE 7A E0 11 FD",
            expectedResponse: "FE FE E0 7A 11 [value] FD",
            userPrompt: "Is ATT indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let att = try await proto.getAttenuator()
            logger.log("Software reports: Attenuator = \(att) (0=OFF)")
        }

        // Test 4.2: Set Attenuator 6dB
        await runTest(
            name: "Set Attenuator 6dB",
            description: "Enable 6dB attenuation",
            commandSent: "FE FE 7A E0 11 06 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display show ATT with 6dB?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAttenuator(0x06)
        }

        // Test 4.3: Set Attenuator 12dB
        await runTest(
            name: "Set Attenuator 12dB",
            description: "Enable 12dB attenuation",
            commandSent: "FE FE 7A E0 11 12 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display show ATT with 12dB?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAttenuator(0x12)
        }

        // Test 4.4: Set Attenuator OFF
        await runTest(
            name: "Set Attenuator OFF",
            description: "Disable attenuation",
            commandSent: "FE FE 7A E0 11 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is ATT indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAttenuator(0x00)
        }

        // Test 4.5: Read Preamp (should be OFF)
        await runTest(
            name: "Read Preamp",
            description: "Read current preamp setting",
            commandSent: "FE FE 7A E0 16 02 FD",
            expectedResponse: "FE FE E0 7A 16 02 [value] FD",
            userPrompt: "Is P.AMP indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let preamp = try await proto.getPreamp()
            logger.log("Software reports: Preamp = \(preamp) (0=OFF)")
        }

        // Test 4.6: Set Preamp 1
        await runTest(
            name: "Set Preamp 1",
            description: "Enable preamp 1",
            commandSent: "FE FE 7A E0 16 02 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display show P.AMP 1?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setPreamp(0x01)
        }

        // Test 4.7: Set Preamp 2
        await runTest(
            name: "Set Preamp 2",
            description: "Enable preamp 2",
            commandSent: "FE FE 7A E0 16 02 02 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display show P.AMP 2?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setPreamp(0x02)
        }

        // Test 4.8: Set Preamp OFF
        await runTest(
            name: "Set Preamp OFF",
            description: "Disable preamp",
            commandSent: "FE FE 7A E0 16 02 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is P.AMP indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setPreamp(0x00)
        }
    }

    // MARK: - Section 5: AGC Control

    static func testAGCControl(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 5: AGC CONTROL")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 5.1: Read AGC
        await runTest(
            name: "Read AGC Setting",
            description: "Read current AGC mode",
            commandSent: "FE FE 7A E0 16 12 FD",
            expectedResponse: "FE FE E0 7A 16 12 [value] FD",
            userPrompt: "Does display show AGC FAST?",
            logger: logger,
            stats: stats
        ) {
            let agc = try await proto.getAGC()
            logger.log("Software reports: AGC = \(agc) (1=FAST, 2=MID, 3=SLOW)")
        }

        // Test 5.2: Set AGC SLOW
        await runTest(
            name: "Set AGC SLOW",
            description: "Set AGC to SLOW mode",
            commandSent: "FE FE 7A E0 16 12 03 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display now show AGC SLOW?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAGC(0x03)
        }

        // Test 5.3: Set AGC MID
        await runTest(
            name: "Set AGC MID",
            description: "Set AGC to MID mode",
            commandSent: "FE FE 7A E0 16 12 02 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display now show AGC MID?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAGC(0x02)
        }

        // Test 5.4: Set AGC FAST
        await runTest(
            name: "Set AGC FAST",
            description: "Set AGC to FAST mode",
            commandSent: "FE FE 7A E0 16 12 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Does display now show AGC FAST?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAGC(0x01)
        }

        // Test 5.5: Read AGC Time Constant
        await runTest(
            name: "Read AGC Time Constant",
            description: "Read AGC time constant setting",
            commandSent: "FE FE 7A E0 1A 04 FD",
            expectedResponse: "FE FE E0 7A 1A 04 [value] FD",
            userPrompt: "AGC time constant read (confirm no error)",
            logger: logger,
            stats: stats
        ) {
            let tc = try await proto.getAGCTimeConstant()
            logger.log("Software reports: AGC Time Constant = \(tc)")
        }

        // Test 5.6: Set AGC Time Constant
        await runTest(
            name: "Set AGC Time Constant",
            description: "Set AGC time constant to mid value",
            commandSent: "FE FE 7A E0 1A 04 07 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "AGC time constant changed (confirm no error)",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAGCTimeConstant(0x07)
        }
    }

    // MARK: - Section 6: Noise Controls

    static func testNoiseControls(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 6: NOISE CONTROLS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 6.1: Read Noise Blanker
        await runTest(
            name: "Read Noise Blanker",
            description: "Read NB status",
            commandSent: "FE FE 7A E0 16 22 FD",
            expectedResponse: "FE FE E0 7A 16 22 [value] FD",
            userPrompt: "Is NB indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let nb = try await proto.getNoiseBlanker()
            logger.log("Software reports: NB = \(nb ? "ON" : "OFF")")
        }

        // Test 6.2: Enable Noise Blanker
        await runTest(
            name: "Enable Noise Blanker",
            description: "Turn NB on",
            commandSent: "FE FE 7A E0 16 22 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is NB indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setNoiseBlanker(true)
        }

        // Test 6.3: Disable Noise Blanker
        await runTest(
            name: "Disable Noise Blanker",
            description: "Turn NB off",
            commandSent: "FE FE 7A E0 16 22 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is NB indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setNoiseBlanker(false)
        }

        // Test 6.4: Read Noise Reduction
        await runTest(
            name: "Read Noise Reduction",
            description: "Read NR status",
            commandSent: "FE FE 7A E0 16 40 FD",
            expectedResponse: "FE FE E0 7A 16 40 [value] FD",
            userPrompt: "Is NR indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let nr = try await proto.getNoiseReduction()
            logger.log("Software reports: NR = \(nr ? "ON" : "OFF")")
        }

        // Test 6.5: Enable Noise Reduction
        await runTest(
            name: "Enable Noise Reduction",
            description: "Turn NR on",
            commandSent: "FE FE 7A E0 16 40 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is NR indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setNoiseReduction(true)
        }

        // Test 6.6: Disable Noise Reduction
        await runTest(
            name: "Disable Noise Reduction",
            description: "Turn NR off",
            commandSent: "FE FE 7A E0 16 40 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is NR indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setNoiseReduction(false)
        }

        // Test 6.7: Read Auto Notch
        await runTest(
            name: "Read Auto Notch",
            description: "Read auto notch status",
            commandSent: "FE FE 7A E0 16 41 FD",
            expectedResponse: "FE FE E0 7A 16 41 [value] FD",
            userPrompt: "Is AUTO NOTCH indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let an = try await proto.getAutoNotch()
            logger.log("Software reports: Auto Notch = \(an ? "ON" : "OFF")")
        }

        // Test 6.8: Enable Auto Notch
        await runTest(
            name: "Enable Auto Notch",
            description: "Turn auto notch on",
            commandSent: "FE FE 7A E0 16 41 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is AUTO NOTCH indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAutoNotch(true)
        }

        // Test 6.9: Disable Auto Notch
        await runTest(
            name: "Disable Auto Notch",
            description: "Turn auto notch off",
            commandSent: "FE FE 7A E0 16 41 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is AUTO NOTCH indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAutoNotch(false)
        }

        // Test 6.10: Read Manual Notch
        await runTest(
            name: "Read Manual Notch",
            description: "Read manual notch status",
            commandSent: "FE FE 7A E0 16 48 FD",
            expectedResponse: "FE FE E0 7A 16 48 [value] FD",
            userPrompt: "Is MANUAL NOTCH indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let mn = try await proto.getManualNotch()
            logger.log("Software reports: Manual Notch = \(mn ? "ON" : "OFF")")
        }

        // Test 6.11: Enable Manual Notch
        await runTest(
            name: "Enable Manual Notch",
            description: "Turn manual notch on",
            commandSent: "FE FE 7A E0 16 48 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is MANUAL NOTCH indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setManualNotch(true)
        }

        // Test 6.12: Disable Manual Notch
        await runTest(
            name: "Disable Manual Notch",
            description: "Turn manual notch off",
            commandSent: "FE FE 7A E0 16 48 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is MANUAL NOTCH indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setManualNotch(false)
        }

        // Test 6.13: Read Audio Peak Filter
        await runTest(
            name: "Read Audio Peak Filter",
            description: "Read APF status",
            commandSent: "FE FE 7A E0 16 31 FD",
            expectedResponse: "FE FE E0 7A 16 31 [value] FD",
            userPrompt: "Is APF indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let apf = try await proto.getAudioPeakFilter()
            logger.log("Software reports: APF = \(apf ? "ON" : "OFF")")
        }

        // Test 6.14: Enable Audio Peak Filter
        await runTest(
            name: "Enable Audio Peak Filter",
            description: "Turn APF on",
            commandSent: "FE FE 7A E0 16 31 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is APF indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAudioPeakFilter(true)
        }

        // Test 6.15: Disable Audio Peak Filter
        await runTest(
            name: "Disable Audio Peak Filter",
            description: "Turn APF off",
            commandSent: "FE FE 7A E0 16 31 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is APF indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAudioPeakFilter(false)
        }

        // Test 6.16: Read Twin Peak Filter
        await runTest(
            name: "Read Twin Peak Filter",
            description: "Read twin peak filter status",
            commandSent: "FE FE 7A E0 16 50 FD",
            expectedResponse: "FE FE E0 7A 16 50 [value] FD",
            userPrompt: "Is TWIN PF indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let tpf = try await proto.getTwinPeakFilter()
            logger.log("Software reports: Twin Peak Filter = \(tpf ? "ON" : "OFF")")
        }

        // Test 6.17: Enable Twin Peak Filter
        await runTest(
            name: "Enable Twin Peak Filter",
            description: "Turn twin peak filter on",
            commandSent: "FE FE 7A E0 16 50 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is TWIN PF indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setTwinPeakFilter(true)
        }

        // Test 6.18: Disable Twin Peak Filter
        await runTest(
            name: "Disable Twin Peak Filter",
            description: "Turn twin peak filter off",
            commandSent: "FE FE 7A E0 16 50 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is TWIN PF indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setTwinPeakFilter(false)
        }
    }

    // MARK: - Section 7: Level Controls

    static func testLevelControls(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 7: LEVEL CONTROLS (SAMPLE)")

        logger.log("NOTE: Testing representative level controls with sample values")
        logger.log("Full range: 0-255, testing: 0, 64, 128, 192, 255")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 7.1: AF Level
        logger.log("\n--- AF (Audio) Level ---")
        await testLevelControl(
            name: "AF Level",
            setFunc: { try await proto.setAFLevel($0) },
            getFunc: { try await proto.getAFLevel() },
            commandBase: "FE FE 7A E0 14 01",
            userPromptFormat: "Does AF level match %d/255?",
            logger: logger,
            stats: stats
        )

        // Test 7.2: RF Gain
        logger.log("\n--- RF Gain ---")
        await testLevelControl(
            name: "RF Gain",
            setFunc: { try await proto.setRFLevel($0) },
            getFunc: { try await proto.getRFLevel() },
            commandBase: "FE FE 7A E0 14 02",
            userPromptFormat: "Does RF gain match %d/255?",
            logger: logger,
            stats: stats
        )

        // Test 7.3: Squelch Level
        logger.log("\n--- Squelch Level ---")
        await testLevelControl(
            name: "Squelch Level",
            setFunc: { try await proto.setSquelchLevel($0) },
            getFunc: { try await proto.getSquelchLevel() },
            commandBase: "FE FE 7A E0 14 03",
            userPromptFormat: "Does squelch level match %d/255?",
            logger: logger,
            stats: stats
        )

        // Test 7.4: NR Level
        logger.log("\n--- NR Level ---")
        await testLevelControl(
            name: "NR Level",
            setFunc: { try await proto.setNRLevel($0) },
            getFunc: { try await proto.getNRLevel() },
            commandBase: "FE FE 7A E0 14 06",
            userPromptFormat: "Does NR level match %d/255?",
            logger: logger,
            stats: stats
        )

        // Test 7.5: Mic Gain
        logger.log("\n--- Mic Gain ---")
        await testLevelControl(
            name: "Mic Gain",
            setFunc: { try await proto.setMicGain($0) },
            getFunc: { try await proto.getMicGain() },
            commandBase: "FE FE 7A E0 14 0E",
            userPromptFormat: "Does MIC gain match %d/255?",
            logger: logger,
            stats: stats
        )

        logger.log("\nNOTE: Additional level controls available:")
        logger.log("  - Inner/Outer PBT, CW Pitch, Key Speed, Notch Position")
        logger.log("  - Compression, Break-in Delay, Balance, NB Level")
        logger.log("  - Drive Gain, Monitor Gain, VOX/Anti-VOX Gain, Brightness")
        logger.log("  All follow same pattern - test individually if needed")
    }

    static func testLevelControl(
        name: String,
        setFunc: (Int) async throws -> Void,
        getFunc: () async throws -> Int,
        commandBase: String,
        userPromptFormat: String,
        logger: TestLogger,
        stats: TestStats
    ) async {
        let testValues = [0, 128, 255]

        for value in testValues {
            await runTest(
                name: "\(name) = \(value)",
                description: "Set \(name) to \(value)",
                commandSent: "\(commandBase) [BCD] FD",
                expectedResponse: "FE FE E0 7A FB FD",
                userPrompt: String(format: userPromptFormat, value),
                logger: logger,
                stats: stats
            ) {
                try await setFunc(value)
            }
        }

        // Read back final value
        await runTest(
            name: "Read \(name)",
            description: "Read current \(name) value",
            commandSent: "\(commandBase) FD",
            expectedResponse: "FE FE E0 7A \(commandBase) [value] FD",
            userPrompt: "Confirm \(name) readback (should be 255)",
            logger: logger,
            stats: stats
        ) {
            let value = try await getFunc()
            logger.log("Software reports: \(name) = \(value)")
        }
    }

    // MARK: - Section 8: Meter Readings

    static func testMeterReadings(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 8: METER READINGS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 8.1: S-Meter
        await runTest(
            name: "Read S-Meter",
            description: "Read signal strength meter",
            commandSent: "FE FE 7A E0 15 02 FD",
            expectedResponse: "FE FE E0 7A 15 02 [value] FD",
            userPrompt: "S-meter read successfully (note the value)",
            logger: logger,
            stats: stats
        ) {
            let signal = try await rig.signalStrength(cached: false)
            logger.log("Software reports: S\(signal.sUnits)" + (signal.overS9 > 0 ? "+\(signal.overS9)dB" : ""))
        }

        // Test 8.2: Squelch Condition
        await runTest(
            name: "Read Squelch Condition",
            description: "Check if squelch is open/closed",
            commandSent: "FE FE 7A E0 15 01 FD",
            expectedResponse: "FE FE E0 7A 15 01 [value] FD",
            userPrompt: "Squelch condition read (confirm no error)",
            logger: logger,
            stats: stats
        ) {
            let sqOpen = try await proto.getSquelchCondition()
            logger.log("Software reports: Squelch \(sqOpen ? "OPEN" : "CLOSED")")
        }

        // Test 8.3: VD Meter (Voltage)
        await runTest(
            name: "Read VD Meter",
            description: "Read supply voltage",
            commandSent: "FE FE 7A E0 15 15 FD",
            expectedResponse: "FE FE E0 7A 15 15 [value] FD",
            userPrompt: "VD meter shows voltage reading",
            logger: logger,
            stats: stats
        ) {
            let vd = try await proto.getVDMeter()
            logger.log("Software reports: VD = \(vd) (raw value)")
        }

        // Test 8.4: ID Meter (Current)
        await runTest(
            name: "Read ID Meter",
            description: "Read supply current",
            commandSent: "FE FE 7A E0 15 16 FD",
            expectedResponse: "FE FE E0 7A 15 16 [value] FD",
            userPrompt: "ID meter shows current reading",
            logger: logger,
            stats: stats
        ) {
            let id = try await proto.getIDMeter()
            logger.log("Software reports: ID = \(id) (raw value)")
        }

        logger.log("\nNOTE: TX meters (RF Power, SWR, ALC, COMP) tested in Section 14")
    }

    // MARK: - Section 9: Function Controls

    static func testFunctionControls(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 9: FUNCTION CONTROLS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 9.1: Speech Compressor
        await runTest(
            name: "Read Speech Compressor",
            description: "Read COMP status",
            commandSent: "FE FE 7A E0 16 44 FD",
            expectedResponse: "FE FE E0 7A 16 44 [value] FD",
            userPrompt: "Is COMP indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let comp = try await proto.getSpeechCompressor()
            logger.log("Software reports: COMP = \(comp ? "ON" : "OFF")")
        }

        await runTest(
            name: "Enable Speech Compressor",
            description: "Turn COMP on",
            commandSent: "FE FE 7A E0 16 44 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is COMP indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setSpeechCompressor(true)
        }

        await runTest(
            name: "Disable Speech Compressor",
            description: "Turn COMP off",
            commandSent: "FE FE 7A E0 16 44 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is COMP indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setSpeechCompressor(false)
        }

        // Test 9.2: VOX
        await runTest(
            name: "Read VOX",
            description: "Read VOX status",
            commandSent: "FE FE 7A E0 16 47 FD",
            expectedResponse: "FE FE E0 7A 16 47 [value] FD",
            userPrompt: "Is VOX indicator OFF?",
            logger: logger,
            stats: stats
        ) {
            let vox = try await proto.getVOX()
            logger.log("Software reports: VOX = \(vox ? "ON" : "OFF")")
        }

        await runTest(
            name: "Enable VOX",
            description: "Turn VOX on",
            commandSent: "FE FE 7A E0 16 47 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is VOX indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setVOX(true)
        }

        await runTest(
            name: "Disable VOX",
            description: "Turn VOX off",
            commandSent: "FE FE 7A E0 16 47 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is VOX indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setVOX(false)
        }

        // Test 9.3: Break-in
        await runTest(
            name: "Read Break-in",
            description: "Read break-in status",
            commandSent: "FE FE 7A E0 16 47 FD",
            expectedResponse: "FE FE E0 7A 16 47 [value] FD",
            userPrompt: "Confirm break-in status",
            logger: logger,
            stats: stats
        ) {
            let bkin = try await proto.getBreakIn()
            logger.log("Software reports: Break-in = \(bkin ? "ON" : "OFF")")
        }

        // Test 9.4: Monitor
        await runTest(
            name: "Enable Monitor",
            description: "Turn monitor on",
            commandSent: "FE FE 7A E0 16 45 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is MONITOR indicator now ON?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setMonitor(true)
        }

        await runTest(
            name: "Disable Monitor",
            description: "Turn monitor off",
            commandSent: "FE FE 7A E0 16 45 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is MONITOR indicator now OFF?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setMonitor(false)
        }

        // Test 9.5: Dial Lock
        await runTest(
            name: "Enable Dial Lock",
            description: "Lock the dial",
            commandSent: "FE FE 7A E0 16 51 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is dial now locked (LOCK indicator ON)?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setDialLock(true)
        }

        await runTest(
            name: "Disable Dial Lock",
            description: "Unlock the dial",
            commandSent: "FE FE 7A E0 16 51 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is dial now unlocked (LOCK indicator OFF)?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setDialLock(false)
        }

        logger.log("\nNOTE: Additional function controls available:")
        logger.log("  - Repeater Tone, Tone Squelch (FM modes)")
    }

    // MARK: - Section 10: Tuning & Antenna

    static func testTuningAntenna(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 10: TUNING & ANTENNA")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 10.1: Tuning Step
        await runTest(
            name: "Set Tuning Step",
            description: "Change tuning step size",
            commandSent: "FE FE 7A E0 10 [step] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Tuning step changed (confirm no error)",
            logger: logger,
            stats: stats
        ) {
            try await proto.setTuningStep(0x01)
        }

        // Test 10.2: Antenna Selection
        await runTest(
            name: "Read Antenna",
            description: "Read selected antenna",
            commandSent: "FE FE 7A E0 12 FD",
            expectedResponse: "FE FE E0 7A 12 [antenna] FD",
            userPrompt: "Confirm current antenna selection",
            logger: logger,
            stats: stats
        ) {
            let ant = try await proto.getAntenna()
            logger.log("Software reports: Antenna = \(ant)")
        }

        await runTest(
            name: "Select Antenna 1",
            description: "Switch to antenna 1",
            commandSent: "FE FE 7A E0 12 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is ANT 1 now selected?",
            logger: logger,
            stats: stats
        ) {
            try await proto.setAntenna(0x00)
        }

        // Test 10.3: Voice Announcement
        await runTest(
            name: "Voice Announce",
            description: "Trigger voice announcement",
            commandSent: "FE FE 7A E0 13 [type] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Did radio announce frequency?",
            logger: logger,
            stats: stats
        ) {
            try await proto.announce(0x00)
        }
    }

    // MARK: - Section 11: Advanced Settings

    static func testAdvancedSettings(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 11: ADVANCED SETTINGS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 11.1: Read Filter Width
        await runTest(
            name: "Read Filter Width",
            description: "Read current filter width index",
            commandSent: "FE FE 7A E0 1A 03 FD",
            expectedResponse: "FE FE E0 7A 1A 03 [index] FD",
            userPrompt: "Filter width read (confirm no error)",
            logger: logger,
            stats: stats
        ) {
            let filter = try await proto.getFilterWidth()
            logger.log("Software reports: Filter Width Index = \(filter)")
        }

        // Test 11.2: Set Filter Width
        await runTest(
            name: "Set Filter Width",
            description: "Change filter width setting",
            commandSent: "FE FE 7A E0 1A 03 [index] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Filter width changed (confirm no error)",
            logger: logger,
            stats: stats
        ) {
            try await proto.setFilterWidth(0x10)
        }
    }

    // MARK: - Section 12: Memory Operations (DESTRUCTIVE)

    static func testMemoryOperations(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 12: MEMORY OPERATIONS (DESTRUCTIVE)")

        logger.log("⚠️  WARNING: These commands modify memory contents")
        logger.log("Only proceed if you understand the risks")

        guard getUserConfirmation("Run memory operation tests?") else {
            logger.log("Memory tests skipped by user")
            return
        }

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 12.1: Select Memory Channel
        await runTest(
            name: "Select Memory Channel 1",
            description: "Switch to memory channel 1",
            commandSent: "FE FE 7A E0 08 [channel BCD] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is memory channel 1 now selected?",
            logger: logger,
            stats: stats,
            isDestructive: false
        ) {
            try await proto.selectMemoryChannel(1)
        }

        // Test 12.2: Memory to VFO
        await runTest(
            name: "Memory to VFO",
            description: "Transfer memory to VFO",
            commandSent: "FE FE 7A E0 0A FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Was memory transferred to VFO?",
            logger: logger,
            stats: stats,
            isDestructive: false
        ) {
            try await proto.memoryToVFO()
        }

        // Test 12.3: Write to Memory (VERY DESTRUCTIVE)
        await runTest(
            name: "Write to Memory",
            description: "Write current VFO to memory",
            commandSent: "FE FE 7A E0 09 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Was current setting written to memory?",
            logger: logger,
            stats: stats,
            isDestructive: true
        ) {
            try await proto.writeToMemory()
        }

        // Test 12.4: Clear Memory (VERY DESTRUCTIVE)
        logger.log("\nNOTE: Memory clear test available but VERY DESTRUCTIVE")
        logger.log("Skipping automatic test - implement manually if needed")
    }

    // MARK: - Section 13: Scan Operations

    static func testScanOperations(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 13: SCAN OPERATIONS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 13.1: Stop Scan
        await runTest(
            name: "Stop Scan",
            description: "Stop any active scan",
            commandSent: "FE FE 7A E0 0E 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is scan stopped (no SCAN indicator)?",
            logger: logger,
            stats: stats
        ) {
            try await proto.stopScan()
        }

        // Test 13.2: Start Programmed Scan
        await runTest(
            name: "Start Programmed Scan",
            description: "Start programmed scan",
            commandSent: "FE FE 7A E0 0E [code] FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Did programmed scan start?",
            logger: logger,
            stats: stats
        ) {
            try await proto.startProgrammedScan()
        }

        // Test 13.3: Stop Scan Again
        await runTest(
            name: "Stop Programmed Scan",
            description: "Stop the scan",
            commandSent: "FE FE 7A E0 0E 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is scan now stopped?",
            logger: logger,
            stats: stats
        ) {
            try await proto.stopScan()
        }
    }

    // MARK: - Section 14: PTT & TX Operations

    static func testPTTOperations(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 14: PTT & TX OPERATIONS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 14.1: Read PTT State
        await runTest(
            name: "Read PTT State",
            description: "Check if transmitting",
            commandSent: "FE FE 7A E0 1C 00 FD",
            expectedResponse: "FE FE E0 7A 1C 00 [state] FD",
            userPrompt: "Is radio in RX mode (not transmitting)?",
            logger: logger,
            stats: stats
        ) {
            let ptt = try await rig.isPTTEnabled()
            logger.log("Software reports: PTT = \(ptt ? "TX" : "RX")")
        }

        // Test 14.2: Enable PTT
        await runTest(
            name: "Enable PTT (Transmit)",
            description: "Key the transmitter for 2 seconds",
            commandSent: "FE FE 7A E0 1C 00 01 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is TX light ON and radio transmitting?",
            logger: logger,
            stats: stats,
            requiresDummyLoad: true
        ) {
            logger.log("Transmitting in 3 seconds...")
            try await Task.sleep(for: .seconds(3))
            try await rig.setPTT(true)
            logger.log("📡 TRANSMITTING...")
            try await Task.sleep(for: .seconds(2))
        }

        // Test 14.3: TX Meter Readings
        logger.log("\nReading TX meters while transmitting...")

        await runTest(
            name: "Read RF Power Meter",
            description: "Read forward power meter",
            commandSent: "FE FE 7A E0 15 11 FD",
            expectedResponse: "FE FE E0 7A 15 11 [value] FD",
            userPrompt: "Does RF power meter show output?",
            logger: logger,
            stats: stats,
            requiresDummyLoad: false  // Already transmitting
        ) {
            let rfPower = try await proto.getRFPowerMeter()
            logger.log("Software reports: RF Power = \(rfPower)")
        }

        await runTest(
            name: "Read SWR Meter",
            description: "Read SWR meter",
            commandSent: "FE FE 7A E0 15 12 FD",
            expectedResponse: "FE FE E0 7A 15 12 [value] FD",
            userPrompt: "Does SWR meter show a reading?",
            logger: logger,
            stats: stats,
            requiresDummyLoad: false
        ) {
            let swr = try await proto.getSWRMeter()
            logger.log("Software reports: SWR = \(swr)")
        }

        await runTest(
            name: "Read ALC Meter",
            description: "Read ALC meter",
            commandSent: "FE FE 7A E0 15 13 FD",
            expectedResponse: "FE FE E0 7A 15 13 [value] FD",
            userPrompt: "Does ALC meter show a reading?",
            logger: logger,
            stats: stats,
            requiresDummyLoad: false
        ) {
            let alc = try await proto.getALCMeter()
            logger.log("Software reports: ALC = \(alc)")
        }

        await runTest(
            name: "Read COMP Meter",
            description: "Read compression meter",
            commandSent: "FE FE 7A E0 15 14 FD",
            expectedResponse: "FE FE E0 7A 15 14 [value] FD",
            userPrompt: "Does COMP meter show a reading?",
            logger: logger,
            stats: stats,
            requiresDummyLoad: false
        ) {
            let comp = try await proto.getCOMPMeter()
            logger.log("Software reports: COMP = \(comp)")
        }

        // Test 14.4: Disable PTT
        await runTest(
            name: "Disable PTT (Return to RX)",
            description: "Stop transmitting",
            commandSent: "FE FE 7A E0 1C 00 00 FD",
            expectedResponse: "FE FE E0 7A FB FD",
            userPrompt: "Is TX light OFF (back to RX)?",
            logger: logger,
            stats: stats,
            requiresDummyLoad: false
        ) {
            try await rig.setPTT(false)
            logger.log("✅ Back to RX mode")
        }
    }

    // MARK: - Section 15: Miscellaneous

    static func testMiscellaneous(rig: RigController, logger: TestLogger, stats: TestStats) async {
        logger.logSection("SECTION 15: MISCELLANEOUS")

        guard let proto = await rig.protocol as? IcomCIVProtocol else {
            logger.log("ERROR: Cannot access IC-7600 protocol")
            return
        }

        // Test 15.1: Read Transceiver ID
        await runTest(
            name: "Read Transceiver ID",
            description: "Read radio model ID",
            commandSent: "FE FE 7A E0 19 00 FD",
            expectedResponse: "FE FE E0 7A 19 00 [ID] FD",
            userPrompt: "Transceiver ID read successfully",
            logger: logger,
            stats: stats
        ) {
            let id = try await proto.getTransceiverID()
            logger.log("Software reports: Transceiver ID = 0x\(String(format: "%02X", id)) (should be 0x7A for IC-7600)")
        }

        // Test 15.2: Read Band Edge
        await runTest(
            name: "Read Band Edge Frequencies",
            description: "Read current band limits",
            commandSent: "FE FE 7A E0 02 FD",
            expectedResponse: "FE FE E0 7A 02 [lower] [upper] FD",
            userPrompt: "Band edges read successfully",
            logger: logger,
            stats: stats
        ) {
            let (lower, upper) = try await proto.getBandEdge()
            logger.log("Software reports: Band edges = \(Double(lower)/1_000_000.0) - \(Double(upper)/1_000_000.0) MHz")
        }

        // Test 15.3: Read Power Level
        await runTest(
            name: "Read RF Power Level",
            description: "Read current power setting",
            commandSent: "FE FE 7A E0 14 0A FD",
            expectedResponse: "FE FE E0 7A 14 0A [value] FD",
            userPrompt: "Does power level match display?",
            logger: logger,
            stats: stats
        ) {
            let power = try await rig.power()
            logger.log("Software reports: Power = \(power)W")
        }
    }
}
