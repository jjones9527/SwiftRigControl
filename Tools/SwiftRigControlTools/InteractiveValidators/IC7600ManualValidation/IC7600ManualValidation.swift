import Foundation
import RigControl

/// IC-7600 Manual Validation Test
/// Interactive test for verifying commands that return invalidResponse
/// This test asks for user confirmation after each command to verify radio state

@main
struct IC7600ManualValidation {
    static func main() async {
        print("======================================================================")
        print("IC-7600 Manual Validation - Interactive Testing")
        print("======================================================================")
        print("This test will send commands and ask you to verify the radio's")
        print("response visually. This helps determine if commands work but")
        print("responses are malformed, or if commands are incorrect.")
        print("======================================================================\n")

        // Get serial port
        guard let serialPort = ProcessInfo.processInfo.environment["IC7600_SERIAL_PORT"] else {
            print("❌ Error: IC7600_SERIAL_PORT environment variable not set")
            print("Usage: export IC7600_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\"")
            return
        }

        print("Configuration:")
        print("  Radio: Icom IC-7600")
        print("  Port: \(serialPort)")
        print("  CI-V Address: 0x7A (default)")
        print("  Baud Rate: 19200\n")

        // Create rig controller
        let rig: RigController
        do {
            rig = try RigController(
                radio: .icomIC7600(civAddress: 0x7A),
                connection: .serial(path: serialPort, baudRate: 19200)
            )
        } catch {
            print("❌ Error creating rig controller: \(error)")
            return
        }

        do {
            // Connect
            print("Connecting to IC-7600...")
            try await rig.connect()
            print("✓ Connected\n")

            // Get protocol
            let proto = await rig.rawProtocol
            guard let icomProtocol = proto as? IcomCIVProtocol else {
                print("❌ Error: Could not access Icom protocol")
                return
            }

            // Test results
            var results: [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)] = []

            // Run tests
            await testPreamp(icomProtocol: icomProtocol, results: &results)
            await testManualNotch(icomProtocol: icomProtocol, results: &results)
            await testTwinPeakFilter(icomProtocol: icomProtocol, rig: rig, results: &results)
            await testBreakIn(icomProtocol: icomProtocol, rig: rig, results: &results)
            await testMonitor(icomProtocol: icomProtocol, results: &results)

            // Print summary
            printSummary(results: results)

            // Disconnect
            await rig.disconnect()
            print("\n✓ Disconnected from IC-7600")

        } catch {
            print("❌ Error: \(error)")
        }
    }

    // MARK: - Test Functions

    static func testPreamp(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        printTestHeader("Preamp Control")

        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0x00, "OFF", "no P.AMP indicator"),
            (0x01, "P.AMP1", "P.AMP 1 indicator"),
            (0x02, "P.AMP2", "P.AMP 2 indicator")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Preamp to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setPreampIC7600(testCase.value)
                print("   ✓ SET command sent successfully")

                // Wait for radio to process
                try await Task.sleep(nanoseconds: 200_000_000)

                // Try to read back
                print("\n📥 Attempting to read Preamp setting...")
                do {
                    let actual = try await icomProtocol.getPreampIC7600()
                    print("   ✓ GET command returned: 0x\(String(format: "%02X", actual))")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (0x\(String(format: "%02X", actual))) doesn't match expected (0x\(String(format: "%02X", testCase.value)))")
                    }

                    results.append((
                        test: "Preamp \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns 0x\(String(format: "%02X", actual)) instead of 0x\(String(format: "%02X", testCase.value))"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")

                    results.append((
                        test: "Preamp \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Preamp \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Reset to OFF
        try? await icomProtocol.setPreampIC7600(0x00)
    }

    static func testManualNotch(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        printTestHeader("Manual Notch Filter")

        let testCases: [(value: Bool, name: String, display: String)] = [
            (true, "ON", "MN indicator visible"),
            (false, "OFF", "no MN indicator")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Manual Notch to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setManualNotchIC7600(testCase.value)
                print("   ✓ SET command sent successfully")

                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Manual Notch setting...")
                do {
                    let actual = try await icomProtocol.getManualNotchIC7600()
                    print("   ✓ GET command returned: \(actual ? "ON" : "OFF")")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual ? "ON" : "OFF")) doesn't match expected (\(testCase.value ? "ON" : "OFF"))")
                    }

                    results.append((
                        test: "Manual Notch \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual ? "ON" : "OFF") instead of \(testCase.value ? "ON" : "OFF")"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")

                    results.append((
                        test: "Manual Notch \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Manual Notch \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Reset to OFF
        try? await icomProtocol.setManualNotchIC7600(false)
    }

    static func testTwinPeakFilter(icomProtocol: IcomCIVProtocol, rig: RigController, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        printTestHeader("Twin Peak Filter (RTTY/PSK mode required)")

        // Save current mode
        let currentMode = (try? await rig.mode(vfo: .main, cached: false)) ?? .usb
        print("Saving current mode: \(currentMode.rawValue)")

        // Switch to RTTY mode (Twin Peak Filter requires RTTY or PSK)
        print("Switching to RTTY mode for Twin Peak Filter test...")
        try? await rig.setMode(.rtty, vfo: .main)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let testCases: [(value: Bool, name: String, display: String)] = [
            (true, "ON", "TPF indicator visible"),
            (false, "OFF", "no TPF indicator")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Twin Peak Filter to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setTwinPeakFilterIC7600(testCase.value)
                print("   ✓ SET command sent successfully")

                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Twin Peak Filter setting...")
                do {
                    let actual = try await icomProtocol.getTwinPeakFilterIC7600()
                    print("   ✓ GET command returned: \(actual ? "ON" : "OFF")")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual ? "ON" : "OFF")) doesn't match expected (\(testCase.value ? "ON" : "OFF"))")
                    }

                    results.append((
                        test: "Twin Peak Filter \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual ? "ON" : "OFF") instead of \(testCase.value ? "ON" : "OFF")"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")

                    results.append((
                        test: "Twin Peak Filter \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Twin Peak Filter \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore mode
        print("\nRestoring mode to \(currentMode.rawValue)...")
        try? await rig.setMode(currentMode, vfo: .main)

        // Reset to OFF
        try? await icomProtocol.setTwinPeakFilterIC7600(false)
    }

    static func testBreakIn(icomProtocol: IcomCIVProtocol, rig: RigController, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        printTestHeader("Break-in (CW mode required)")

        // Save current mode
        let currentMode = (try? await rig.mode(vfo: .main, cached: false)) ?? .usb
        print("Saving current mode: \(currentMode.rawValue)")

        // Switch to CW mode
        print("Switching to CW mode for break-in test...")
        try? await rig.setMode(.cw, vfo: .main)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let testCases: [(value: Bool, name: String, display: String)] = [
            (true, "ON", "BK-IN indicator visible (Semi or Full)"),
            (false, "OFF", "no BK-IN indicator")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Break-in to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")
            if testCase.value {
                print("   Note: Current API sets to Semi (0x01), not Full (0x02)")
            }

            do {
                try await icomProtocol.setBreakInIC7600(testCase.value)
                print("   ✓ SET command sent successfully")

                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Break-in setting...")
                do {
                    let actual = try await icomProtocol.getBreakInIC7600()
                    print("   ✓ GET command returned: \(actual ? "ON" : "OFF")")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual ? "ON" : "OFF")) doesn't match expected (\(testCase.value ? "ON" : "OFF"))")
                    }

                    results.append((
                        test: "Break-in \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual ? "ON" : "OFF") instead of \(testCase.value ? "ON" : "OFF")"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")

                    results.append((
                        test: "Break-in \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Break-in \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore mode
        print("\nRestoring mode to \(currentMode.rawValue)...")
        try? await rig.setMode(currentMode, vfo: .main)

        // Reset to OFF
        try? await icomProtocol.setBreakInIC7600(false)
    }

    static func testMonitor(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        printTestHeader("Monitor Function")

        let testCases: [(value: Bool, name: String, display: String)] = [
            (true, "ON", "Monitor indicator visible"),
            (false, "OFF", "no Monitor indicator")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Monitor to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setMonitorIC7600(testCase.value)
                print("   ✓ SET command sent successfully")

                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Monitor setting...")
                do {
                    let actual = try await icomProtocol.getMonitorIC7600()
                    print("   ✓ GET command returned: \(actual ? "ON" : "OFF")")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual ? "ON" : "OFF")) doesn't match expected (\(testCase.value ? "ON" : "OFF"))")
                    }

                    results.append((
                        test: "Monitor \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual ? "ON" : "OFF") instead of \(testCase.value ? "ON" : "OFF")"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")

                    results.append((
                        test: "Monitor \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Monitor \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Reset to OFF
        try? await icomProtocol.setMonitorIC7600(false)
    }

    // MARK: - Helper Functions

    static func printTestHeader(_ title: String) {
        print("\n======================================================================")
        print("Testing: \(title)")
        print("======================================================================")
    }

    static func askUser(_ question: String) async -> Bool {
        print("\n❓ \(question)")
        print("   Enter 'y' for yes, 'n' for no: ", terminator: "")
        fflush(stdout)

        guard let response = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return false
        }

        return response == "y" || response == "yes"
    }

    static func printSummary(results: [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) {
        print("\n\n======================================================================")
        print("VALIDATION SUMMARY")
        print("======================================================================\n")

        var commandsWork = 0
        var responsesWork = 0
        let total = results.count

        for result in results {
            let commandStatus = result.commandWorks ? "✓ Command Works" : "✗ Command Failed"
            let responseStatus = result.responseWorks ? "✓ Response OK" : "✗ Response Issue"

            print("[\(commandStatus)] [\(responseStatus)] \(result.test)")
            print("  └─ \(result.notes)\n")

            if result.commandWorks { commandsWork += 1 }
            if result.responseWorks { responsesWork += 1 }
        }

        print("======================================================================")
        print("Results:")
        print("  Commands Working: \(commandsWork)/\(total) (\(Int(Double(commandsWork)/Double(total) * 100))%)")
        print("  Responses Working: \(responsesWork)/\(total) (\(Int(Double(responsesWork)/Double(total) * 100))%)")
        print("======================================================================\n")

        // Analysis
        if commandsWork == total && responsesWork == total {
            print("✅ EXCELLENT: All commands work and responses are correct!")
            print("   The API is ready for distribution.")
        } else if commandsWork == total && responsesWork < total {
            print("⚠️  GOOD: All commands work correctly on the radio!")
            print("   However, some GET commands return invalidResponse.")
            print("   This suggests:")
            print("   • SET commands are correct and control the radio properly")
            print("   • GET command response parsing needs investigation")
            print("   • The API can be used for SET operations reliably")
            print("   • GET operations may need response format fixes")
        } else if commandsWork < total {
            print("❌ ISSUE: Some commands don't work correctly!")
            print("   This suggests:")
            print("   • Command codes or parameters may be incorrect")
            print("   • Radio may require specific mode or state")
            print("   • Further manual investigation needed")
        }
    }
}
