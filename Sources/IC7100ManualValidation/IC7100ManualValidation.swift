import Foundation
import RigControl

/// Manual validation tool for IC-7100 failing commands
/// Tests commands interactively with user confirmation
@main
struct IC7100ManualValidation {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-7100 Manual Command Validation")
        print("Interactive testing of failing commands")
        print(String(repeating: "=", count: 70) + "\n")

        guard let serialPort = ProcessInfo.processInfo.environment["IC7100_SERIAL_PORT"] else {
            print("❌ Error: IC7100_SERIAL_PORT environment variable not set")
            print("   Usage: IC7100_SERIAL_PORT=/dev/cu.usbserial-XXXX swift run IC7100ManualValidation")
            Foundation.exit(1)
        }

        print("Configuration:")
        print("  Serial Port: \(serialPort)")
        print("  Radio: IC-7100 (CI-V Address: 0x88)")
        print("  Baud Rate: 19200")
        print("\n" + String(repeating: "-", count: 70))
        print("This tool will send commands and ask you to confirm what you see")
        print("on the radio display. This helps verify if commands work even if")
        print("we're not parsing responses correctly.")
        print(String(repeating: "-", count: 70) + "\n")

        let rig: RigController
        do {
            rig = try RigController(
                radio: .icomIC7100(civAddress: 0x88),
                connection: .serial(path: serialPort, baudRate: 19200)
            )
        } catch {
            print("❌ Error creating rig controller: \(error)")
            Foundation.exit(1)
        }

        do {
            try await rig.connect()
            print("✅ Connected to IC-7100\n")
        } catch {
            print("❌ Connection failed: \(error)")
            Foundation.exit(1)
        }

        let proto = await rig.protocol
        guard let icomProtocol = proto as? IcomCIVProtocol else {
            print("❌ Error: Not an Icom protocol")
            await rig.disconnect()
            Foundation.exit(1)
        }

        var results: [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)] = []

        // Test 1: Attenuator
        await testAttenuator(icomProtocol: icomProtocol, results: &results)

        // Test 2: Preamp
        await testPreamp(icomProtocol: icomProtocol, results: &results)

        // Test 3: AGC
        await testAGC(icomProtocol: icomProtocol, results: &results)

        // Test 4: Inner PBT
        await testInnerPBT(icomProtocol: icomProtocol, results: &results)

        // Test 5: Outer PBT
        await testOuterPBT(icomProtocol: icomProtocol, results: &results)

        // Test 6: VOX Gain
        await testVOXGain(icomProtocol: icomProtocol, results: &results)

        // Test 7: LCD Backlight
        await testLCDBacklight(icomProtocol: icomProtocol, results: &results)

        // Test 8: LCD Contrast
        await testLCDContrast(icomProtocol: icomProtocol, results: &results)

        // Disconnect
        await rig.disconnect()
        print("\n✅ Disconnected from IC-7100\n")

        // Print summary
        printSummary(results)
    }

    // MARK: - Test Functions

    static func testAttenuator(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Attenuator (Command 0x11)")
        print(String(repeating: "=", count: 70))

        // IC-7100 only supports OFF or ON (12dB attenuation)
        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0x00, "OFF", "ATT should be OFF"),
            (0x12, "ON", "ATT should be ON")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Attenuator to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setAttenuatorIC7100(testCase.value)
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Attenuator setting...")
                do {
                    let actual = try await icomProtocol.getAttenuatorIC7100()
                    print("   ✓ GET command returned: 0x\(String(format: "%02X", actual))")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (0x\(String(format: "%02X", actual))) doesn't match expected (0x\(String(format: "%02X", testCase.value)))")
                    }

                    results.append((
                        test: "Attenuator \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns 0x\(String(format: "%02X", actual)) instead of 0x\(String(format: "%02X", testCase.value))"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    results.append((
                        test: "Attenuator \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Attenuator \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Turn attenuator off
        do {
            try await icomProtocol.setAttenuatorIC7100(0x00)
            print("\n🔄 Attenuator turned OFF")
        } catch {
            print("\n⚠️  Could not turn attenuator OFF: \(error)")
        }
    }

    static func testPreamp(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Preamp (Command 0x16 0x02)")
        print(String(repeating: "=", count: 70))

        // IC-7100 only supports OFF or ON (preamp enabled)
        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0x00, "OFF", "Preamp should be OFF"),
            (0x01, "ON", "Preamp should be ON")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Preamp to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setPreampIC7100(testCase.value)
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Preamp setting...")
                do {
                    let actual = try await icomProtocol.getPreampIC7100()
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
    }

    static func testAGC(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: AGC (Command 0x16 0x12)")
        print(String(repeating: "=", count: 70))

        let testCases: [(value: UInt8, name: String, display: String)] = [
            (0x01, "FAST", "AGC FAST"),
            (0x02, "MID", "AGC MID"),
            (0x03, "SLOW", "AGC SLOW")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set AGC to \(testCase.name)")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setAGCIC7100(testCase.value)
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read AGC setting...")
                do {
                    let actual = try await icomProtocol.getAGCIC7100()
                    print("   ✓ GET command returned: 0x\(String(format: "%02X", actual))")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (0x\(String(format: "%02X", actual))) doesn't match expected (0x\(String(format: "%02X", testCase.value)))")
                    }

                    results.append((
                        test: "AGC \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns 0x\(String(format: "%02X", actual)) instead of 0x\(String(format: "%02X", testCase.value))"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    results.append((
                        test: "AGC \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "AGC \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }
    }

    static func testInnerPBT(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Inner PBT (Command 0x14 0x07)")
        print(String(repeating: "=", count: 70))

        let testCases: [(value: Int, name: String, display: String)] = [
            (128, "Center", "PBT centered or no PBT indicator"),
            (200, "+Shift", "PBT shifted positive"),
            (50, "-Shift", "PBT shifted negative")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Inner PBT to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setInnerPBTIC7100(UInt8(testCase.value))
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Inner PBT setting...")
                do {
                    let actual = try await icomProtocol.getInnerPBTIC7100()
                    print("   ✓ GET command returned: \(actual)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual)) doesn't match expected (\(testCase.value))")
                    }

                    results.append((
                        test: "Inner PBT \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual) instead of \(testCase.value)"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    results.append((
                        test: "Inner PBT \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Inner PBT \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Reset to center
        do {
            try await icomProtocol.setInnerPBTIC7100(128)
            print("\n🔄 Inner PBT reset to center")
        } catch {
            print("\n⚠️  Could not reset Inner PBT: \(error)")
        }
    }

    static func testOuterPBT(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: Outer PBT (Command 0x14 0x08)")
        print(String(repeating: "=", count: 70))

        let testCases: [(value: Int, name: String, display: String)] = [
            (128, "Center", "PBT centered or no PBT indicator"),
            (200, "+Shift", "PBT shifted positive"),
            (50, "-Shift", "PBT shifted negative")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set Outer PBT to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setOuterPBTIC7100(UInt8(testCase.value))
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read Outer PBT setting...")
                do {
                    let actual = try await icomProtocol.getOuterPBTIC7100()
                    print("   ✓ GET command returned: \(actual)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual)) doesn't match expected (\(testCase.value))")
                    }

                    results.append((
                        test: "Outer PBT \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual) instead of \(testCase.value)"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    results.append((
                        test: "Outer PBT \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "Outer PBT \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Reset to center
        do {
            try await icomProtocol.setOuterPBTIC7100(128)
            print("\n🔄 Outer PBT reset to center")
        } catch {
            print("\n⚠️  Could not reset Outer PBT: \(error)")
        }
    }

    static func testVOXGain(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: VOX Gain (Command 0x14 0x16)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getVoxGainIC7100()
            print("\n💾 Saved original VOX Gain: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original VOX Gain: \(error)")
        }

        // VOX Gain: 0-255 = 0-100%
        let testCases: [(value: Int, name: String, display: String)] = [
            (0, "0%", "VOX gain at 0%"),
            (128, "50%", "VOX gain at 50%"),
            (255, "100%", "VOX gain at 100%")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set VOX Gain to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setVoxGainIC7100(UInt8(testCase.value))
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 200_000_000)

                print("\n📥 Attempting to read VOX Gain setting...")
                do {
                    let actual = try await icomProtocol.getVoxGainIC7100()
                    print("   ✓ GET command returned: \(actual)")

                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual)) doesn't match expected (\(testCase.value))")
                    }

                    results.append((
                        test: "VOX Gain \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual) instead of \(testCase.value)"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the radio display show \(testCase.display)?")
                    results.append((
                        test: "VOX Gain \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
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
                try await icomProtocol.setVoxGainIC7100(original)
                print("\n🔄 VOX Gain restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore VOX Gain: \(error)")
            }
        }
    }

    static func testLCDBacklight(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: LCD Backlight (Command 0x14 0x03)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getLCDBacklightIC7100()
            print("\n💾 Saved original LCD Backlight: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original LCD Backlight: \(error)")
        }

        let testCases: [(value: Int, name: String, display: String)] = [
            (50, "Dim", "Display should be dimmer"),
            (200, "Bright", "Display should be brighter")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set LCD Backlight to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setLCDBacklightIC7100(UInt8(testCase.value))
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 500_000_000)  // Longer delay to observe brightness change

                print("\n📥 Attempting to read LCD Backlight setting...")
                do {
                    let actual = try await icomProtocol.getLCDBacklightIC7100()
                    print("   ✓ GET command returned: \(actual)")

                    let commandWorks = await askUser("Did the display brightness change to \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual)) doesn't match expected (\(testCase.value))")
                    }

                    results.append((
                        test: "LCD Backlight \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual) instead of \(testCase.value)"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the display brightness change to \(testCase.display)?")
                    results.append((
                        test: "LCD Backlight \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "LCD Backlight \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setLCDBacklightIC7100(original)
                print("\n🔄 LCD Backlight restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore LCD Backlight: \(error)")
            }
        }
    }

    static func testLCDContrast(icomProtocol: IcomCIVProtocol, results: inout [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) async {
        print("\n" + String(repeating: "=", count: 70))
        print("TEST: LCD Contrast (Command 0x14 0x04)")
        print(String(repeating: "=", count: 70))

        // Read and save original value
        var originalValue: UInt8?
        do {
            originalValue = try await icomProtocol.getLCDContrastIC7100()
            print("\n💾 Saved original LCD Contrast: \(originalValue!)")
        } catch {
            print("\n⚠️  Could not read original LCD Contrast: \(error)")
        }

        let testCases: [(value: Int, name: String, display: String)] = [
            (50, "Low", "Display contrast should be lower"),
            (200, "High", "Display contrast should be higher")
        ]

        for testCase in testCases {
            print("\n📤 Sending: Set LCD Contrast to \(testCase.name) (value: \(testCase.value))")
            print("   Expected on radio: \(testCase.display)")

            do {
                try await icomProtocol.setLCDContrastIC7100(UInt8(testCase.value))
                print("   ✓ SET command sent successfully")
                try await Task.sleep(nanoseconds: 500_000_000)  // Longer delay to observe contrast change

                print("\n📥 Attempting to read LCD Contrast setting...")
                do {
                    let actual = try await icomProtocol.getLCDContrastIC7100()
                    print("   ✓ GET command returned: \(actual)")

                    let commandWorks = await askUser("Did the display contrast change to \(testCase.display)?")
                    let responseCorrect = (actual == testCase.value)

                    if responseCorrect {
                        print("   ✓ Response matches expected value")
                    } else {
                        print("   ⚠️  Response (\(actual)) doesn't match expected (\(testCase.value))")
                    }

                    results.append((
                        test: "LCD Contrast \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: responseCorrect,
                        notes: responseCorrect ? "SET and GET work correctly" : "SET works, GET returns \(actual) instead of \(testCase.value)"
                    ))
                } catch {
                    print("   ❌ GET command failed: \(error)")
                    let commandWorks = await askUser("Did the display contrast change to \(testCase.display)?")
                    results.append((
                        test: "LCD Contrast \(testCase.name)",
                        commandWorks: commandWorks,
                        responseWorks: false,
                        notes: "SET works, GET fails with: \(error)"
                    ))
                }
            } catch {
                print("   ❌ SET command failed: \(error)")
                results.append((
                    test: "LCD Contrast \(testCase.name)",
                    commandWorks: false,
                    responseWorks: false,
                    notes: "SET command failed: \(error)"
                ))
            }
        }

        // Restore original value
        if let original = originalValue {
            do {
                try await icomProtocol.setLCDContrastIC7100(original)
                print("\n🔄 LCD Contrast restored to original value: \(original)")
            } catch {
                print("\n⚠️  Could not restore LCD Contrast: \(error)")
            }
        }
    }

    // MARK: - Helper Functions

    static func askUser(_ question: String) async -> Bool {
        print("\n❓ \(question)")
        print("   Enter 'y' for YES or 'n' for NO: ", terminator: "")

        guard let input = readLine()?.lowercased() else {
            return false
        }

        return input == "y" || input == "yes"
    }

    static func printSummary(_ results: [(test: String, commandWorks: Bool, responseWorks: Bool, notes: String)]) {
        print(String(repeating: "=", count: 70))
        print("VALIDATION SUMMARY")
        print(String(repeating: "=", count: 70))

        var commandsWorking = 0
        var responsesWorking = 0
        let totalTests = results.count

        for result in results {
            let commandStatus = result.commandWorks ? "✅" : "❌"
            let responseStatus = result.responseWorks ? "✅" : "❌"

            print("\n\(result.test):")
            print("  Command works: \(commandStatus) \(result.commandWorks ? "YES" : "NO")")
            print("  Response works: \(responseStatus) \(result.responseWorks ? "YES" : "NO")")
            print("  Notes: \(result.notes)")

            if result.commandWorks { commandsWorking += 1 }
            if result.responseWorks { responsesWorking += 1 }
        }

        print("\n" + String(repeating: "=", count: 70))
        print("FINAL RESULTS")
        print(String(repeating: "=", count: 70))
        print("Commands Working: \(commandsWorking)/\(totalTests) (\(commandsWorking * 100 / max(totalTests, 1))%)")
        print("Responses Working: \(responsesWorking)/\(totalTests) (\(responsesWorking * 100 / max(totalTests, 1))%)")
        print(String(repeating: "=", count: 70) + "\n")

        if commandsWorking == totalTests && responsesWorking == totalTests {
            print("🎉 Perfect! All commands and responses work correctly!\n")
        } else if commandsWorking == totalTests {
            print("✅ All commands work, but some responses need fixing.\n")
        } else {
            print("⚠️  Some commands are not supported or need investigation.\n")
        }
    }
}
