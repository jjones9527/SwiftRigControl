import Foundation
import RigControl

/// Interactive validation tool for IC-9700 Level commands (Command 0x14)
///
/// This tool tests the Level commands that were fixed for BCD byte order issues.
/// It performs interactive validation by:
/// 1. Reading current values before testing
/// 2. Setting test values and asking user to confirm on radio display
/// 3. Reading back values to verify command/response handling
/// 4. Restoring original values after testing
///
/// Usage:
///   IC9700_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC9700ManualValidation
///
@main
struct IC9700ManualValidation {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-9700 Manual Command Validation")
        print("Interactive testing of Level commands (0x14)")
        print(String(repeating: "=", count: 70))

        guard let serialPort = ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"] else {
            print("\n❌ Error: IC9700_SERIAL_PORT environment variable not set")
            print("   Usage: IC9700_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run IC9700ManualValidation")
            return
        }

        print("\nConfiguration:")
        print("  Serial Port: \(serialPort)")
        print("  Radio: IC-9700 (CI-V Address: 0xA2)")
        print("  Baud Rate: 19200")

        print("\n" + String(repeating: "-", count: 70))
        print("This tool will send commands and ask you to confirm what you see")
        print("on the radio display. This helps verify if commands work even if")
        print("we're not parsing responses correctly.")
        print(String(repeating: "-", count: 70))

        var results: [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)] = []

        do {
            let rig = try RigController(
                radio: .icomIC9700(civAddress: nil),
                connection: .serial(path: serialPort, baudRate: 19200)
            )

            try await rig.connect()
            print("\n✅ Connected to IC-9700\n")

            let proto = await rig.protocol
            guard let icomProtocol = proto as? IcomCIVProtocol else {
                print("❌ Error: Not an Icom protocol")
                await rig.disconnect()
                return
            }

            // Test NR Level
            await testNRLevel(icomProtocol: icomProtocol, results: &results)

            // Test Notch Position
            await testNotchPosition(icomProtocol: icomProtocol, results: &results)

            // Test Monitor Gain
            await testMonitorGain(icomProtocol: icomProtocol, results: &results)

            // Test VOX Gain
            await testVOXGain(icomProtocol: icomProtocol, results: &results)

            // Test Anti-VOX Gain
            await testAntiVOXGain(icomProtocol: icomProtocol, results: &results)

            await rig.disconnect()
            print("✅ Disconnected from IC-9700\n")

        } catch {
            print("\n❌ Error: \(error)")
        }

        // Print summary
        printSummary(results: results)
    }

    // MARK: - Test Functions

    static func testNRLevel(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: NR Level (Command 0x14 0x06)")
        print(String(repeating: "=", count: 70))
        print("\nNOTE: IC-9700 displays NR Level as 0-15, CI-V protocol uses 0-255")
        print("      CI-V 0 = Display 0, CI-V 128 ≈ Display 8, CI-V 255 = Display 15")

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getNRLevelIC9700()
            let displayValue = Int(Double(originalValue!) / 255.0 * 15.0 + 0.5)
            print("\n💾 Saved original NR Level: \(originalValue!) (display: ~\(displayValue))")
        } catch {
            print("\n⚠️  Could not read original NR Level: \(error)")
        }

        // NR Level: CI-V 0-255 maps to display 0-15
        let testCases: [(value: UInt8, name: String, displayValue: Int)] = [
            (0, "0%", 0),      // 0/255 * 15 = 0
            (128, "50%", 8),   // 128/255 * 15 ≈ 7.5 → 8
            (255, "100%", 15)  // 255/255 * 15 = 15
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set NR Level to \(testCase.name) (CI-V value: \(testCase.value))")
            print("   Expected radio display: NR Level = \(testCase.displayValue)")

            do {
                try await icomProtocol.setNRLevelIC9700(testCase.value)
                print("   ✓ SET command sent successfully")

                print("\n📥 Attempting to read NR Level setting...")
                let readValue = try await icomProtocol.getNRLevelIC9700()
                let readDisplayValue = Int(Double(readValue) / 255.0 * 15.0 + 0.5)
                print("   ✓ GET command returned: \(readValue) (display: ~\(readDisplayValue))")

                let userConfirmed = await askUser("Did the radio display show NR Level = \(testCase.displayValue)?")

                let responseMatches = readValue == testCase.value
                if responseMatches {
                    print("   ✓ Response matches expected value")
                } else {
                    print("   ⚠️  Response mismatch: expected \(testCase.value), got \(readValue)")
                }

                results.append((
                    test: "NR Level \(testCase.name) (Display: \(testCase.displayValue))",
                    commandWorks: userConfirmed,
                    responseWorks: responseMatches,
                    notes: "CI-V value \(testCase.value) → Display \(testCase.displayValue)"
                ))
            } catch {
                print("   ❌ Command failed: \(error)")
                results.append((
                    test: "NR Level \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setNRLevelIC9700(original)
                let displayValue = Int(Double(original) / 255.0 * 15.0 + 0.5)
                print("\n🔄 NR Level restored to original: \(original) (display: ~\(displayValue))")
            } catch {
                print("\n⚠️  Could not restore NR Level: \(error)")
            }
        }
    }

    static func testNotchPosition(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Notch Position (Command 0x14 0x0D)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getNotchPositionIC9700()
            print("\n💾 Saved original Notch Position: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original Notch Position: \(error)")
        }

        // Notch Position: 0-255 (center=128)
        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0, "Min", "Notch at minimum position"),
            (128, "Center", "Notch at center position"),
            (255, "Max", "Notch at maximum position")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Notch Position to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setNotchPositionIC9700(testCase.value)
                print("   ✓ SET command sent successfully")

                print("\n📥 Attempting to read Notch Position...")
                let readValue = try await icomProtocol.getNotchPositionIC9700()
                print("   ✓ GET command returned: \(readValue)")

                let userConfirmed = await askUser("Did the radio display show \(testCase.display)?")

                let responseMatches = readValue == testCase.value
                if responseMatches {
                    print("   ✓ Response matches expected value")
                } else {
                    print("   ⚠️  Response mismatch: expected \(testCase.value), got \(readValue)")
                }

                results.append((
                    test: "Notch Position \(testCase.name)",
                    commandWorks: userConfirmed,
                    responseWorks: responseMatches,
                    notes: "SET and GET work correctly"
                ))
            } catch {
                print("   ❌ Command failed: \(error)")
                results.append((
                    test: "Notch Position \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setNotchPositionIC9700(original)
                print("\n🔄 Notch Position restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore Notch Position: \(error)")
            }
        }
    }

    static func testMonitorGain(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Monitor Gain (Command 0x14 0x15)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getMonitorGainIC9700()
            print("\n💾 Saved original Monitor Gain: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original Monitor Gain: \(error)")
        }

        // Monitor Gain: 0-255 = 0-100%
        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0, "0%", "Monitor gain at 0%"),
            (128, "50%", "Monitor gain at 50%"),
            (255, "100%", "Monitor gain at 100%")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Monitor Gain to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setMonitorGainIC9700(testCase.value)
                print("   ✓ SET command sent successfully")

                print("\n📥 Attempting to read Monitor Gain...")
                let readValue = try await icomProtocol.getMonitorGainIC9700()
                print("   ✓ GET command returned: \(readValue)")

                let userConfirmed = await askUser("Did the radio display show \(testCase.display)?")

                let responseMatches = readValue == testCase.value
                if responseMatches {
                    print("   ✓ Response matches expected value")
                } else {
                    print("   ⚠️  Response mismatch: expected \(testCase.value), got \(readValue)")
                }

                results.append((
                    test: "Monitor Gain \(testCase.name)",
                    commandWorks: userConfirmed,
                    responseWorks: responseMatches,
                    notes: "SET and GET work correctly"
                ))
            } catch {
                print("   ❌ Command failed: \(error)")
                results.append((
                    test: "Monitor Gain \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setMonitorGainIC9700(original)
                print("\n🔄 Monitor Gain restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore Monitor Gain: \(error)")
            }
        }
    }

    static func testVOXGain(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: VOX Gain (Command 0x14 0x16)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getVoxGainIC9700()
            print("\n💾 Saved original VOX Gain: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original VOX Gain: \(error)")
        }

        // VOX Gain: 0-255 = 0-100%
        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0, "0%", "VOX gain at 0%"),
            (128, "50%", "VOX gain at 50%"),
            (255, "100%", "VOX gain at 100%")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set VOX Gain to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setVoxGainIC9700(testCase.value)
                print("   ✓ SET command sent successfully")

                print("\n📥 Attempting to read VOX Gain...")
                let readValue = try await icomProtocol.getVoxGainIC9700()
                print("   ✓ GET command returned: \(readValue)")

                let userConfirmed = await askUser("Did the radio display show \(testCase.display)?")

                let responseMatches = readValue == testCase.value
                if responseMatches {
                    print("   ✓ Response matches expected value")
                } else {
                    print("   ⚠️  Response mismatch: expected \(testCase.value), got \(readValue)")
                }

                results.append((
                    test: "VOX Gain \(testCase.name)",
                    commandWorks: userConfirmed,
                    responseWorks: responseMatches,
                    notes: "SET and GET work correctly"
                ))
            } catch {
                print("   ❌ Command failed: \(error)")
                results.append((
                    test: "VOX Gain \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setVoxGainIC9700(original)
                print("\n🔄 VOX Gain restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore VOX Gain: \(error)")
            }
        }
    }

    static func testAntiVOXGain(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Anti-VOX Gain (Command 0x14 0x17)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getAntiVoxGainIC9700()
            print("\n💾 Saved original Anti-VOX Gain: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original Anti-VOX Gain: \(error)")
        }

        // Anti-VOX Gain: 0-255 = 0-100%
        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0, "0%", "Anti-VOX gain at 0%"),
            (128, "50%", "Anti-VOX gain at 50%"),
            (255, "100%", "Anti-VOX gain at 100%")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Anti-VOX Gain to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setAntiVoxGainIC9700(testCase.value)
                print("   ✓ SET command sent successfully")

                print("\n📥 Attempting to read Anti-VOX Gain...")
                let readValue = try await icomProtocol.getAntiVoxGainIC9700()
                print("   ✓ GET command returned: \(readValue)")

                let userConfirmed = await askUser("Did the radio display show \(testCase.display)?")

                let responseMatches = readValue == testCase.value
                if responseMatches {
                    print("   ✓ Response matches expected value")
                } else {
                    print("   ⚠️  Response mismatch: expected \(testCase.value), got \(readValue)")
                }

                results.append((
                    test: "Anti-VOX Gain \(testCase.name)",
                    commandWorks: userConfirmed,
                    responseWorks: responseMatches,
                    notes: "SET and GET work correctly"
                ))
            } catch {
                print("   ❌ Command failed: \(error)")
                results.append((
                    test: "Anti-VOX Gain \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setAntiVoxGainIC9700(original)
                print("\n🔄 Anti-VOX Gain restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore Anti-VOX Gain: \(error)")
            }
        }
    }

    // MARK: - Helper Functions

    static func askUser(_ question: String) async -> Bool {
        print("\n❓ \(question)")
        print("   Enter 'y' for YES or 'n' for NO: ", terminator: "")
        fflush(stdout)

        if let response = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) {
            return response == "y" || response == "yes"
        }
        return false
    }

    static func printSummary(results: [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) {
        print("\n" + String(repeating: "=", count: 70))
        print("VALIDATION SUMMARY")
        print(String(repeating: "=", count: 70))
        print()

        for result in results {
            print("\(result.test):")
            print("  Command works: \(result.commandWorks ? "✅ YES" : "❌ NO")")
            print("  Response works: \(result.responseWorks ? "✅ YES" : "❌ NO")")
            print("  Notes: \(result.notes)")
            print()
        }

        let commandsWorking = results.filter { $0.commandWorks }.count
        let responsesWorking = results.filter { $0.responseWorks }.count
        let total = results.count

        print(String(repeating: "=", count: 70))
        print("FINAL RESULTS")
        print(String(repeating: "=", count: 70))
        print("Commands Working: \(commandsWorking)/\(total) (\(commandsWorking * 100 / max(total, 1))%)")
        print("Responses Working: \(responsesWorking)/\(total) (\(responsesWorking * 100 / max(total, 1))%)")
        print(String(repeating: "=", count: 70))
        print()

        if commandsWorking == total && responsesWorking == total {
            print("✅ All Level commands working correctly!")
        } else {
            print("⚠️  Some commands need investigation.")
        }
    }
}
