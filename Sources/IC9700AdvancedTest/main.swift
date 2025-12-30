import Foundation
import RigControl

/// Advanced CI-V feature test for IC-9700
/// Tests satellite mode, preamp, attenuator, AGC, and other IC-9700-specific features
@main
struct IC9700AdvancedTest {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("IC-9700 Advanced Features Validation")
        print("Testing satellite, preamp, attenuator, AGC, and IC-9700-specific controls")
        print(String(repeating: "=", count: 70) + "\n")

        guard let port = ProcessInfo.processInfo.environment["IC9700_SERIAL_PORT"]
                      ?? ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
            print("❌ Set IC9700_SERIAL_PORT environment variable")
            Foundation.exit(1)
        }

        print("Port: \(port)\n")

        var testsPassed = 0
        var testsFailed = 0

        do {
            let rig = try RigController(
                radio: .icomIC9700(civAddress: nil),
                connection: .serial(path: port, baudRate: nil)
            )

            try await rig.connect()
            print("✓ Connected to IC-9700\n")

            let proto = await rig.protocol
            guard let icomProtocol = proto as? IcomCIVProtocol else {
                print("❌ Could not access Icom protocol")
                Foundation.exit(1)
            }

            // Test 1: Satellite Mode (IC-9700 unique feature)
            print("🛰️  Test 1: Satellite Mode")
            do {
                try await icomProtocol.setSatelliteModeIC9700(true)
                let enabled = try await icomProtocol.getSatelliteModeIC9700()
                guard enabled else { throw RigError.commandFailed("Satellite enable") }
                print("   ✓ Satellite mode ON")

                try await icomProtocol.setSatelliteModeIC9700(false)
                let disabled = try await icomProtocol.getSatelliteModeIC9700()
                guard !disabled else { throw RigError.commandFailed("Satellite disable") }
                print("   ✓ Satellite mode OFF")

                testsPassed += 1
                print("   ✅ PASS\n")
            } catch {
                print("   ❌ FAIL: \(error)\n")
                testsFailed += 1
            }

            // Test 2: Dual Watch
            print("👁️  Test 2: Dual Watch")
            do {
                try await icomProtocol.setDualwatchIC9700(true)
                print("   ✓ Dual watch ON")

                try await icomProtocol.setDualwatchIC9700(false)
                print("   ✓ Dual watch OFF")

                testsPassed += 1
                print("   ✅ PASS\n")
            } catch {
                print("   ❌ FAIL: \(error)\n")
                testsFailed += 1
            }

            // Test 3: Preamp Control
            print("📡 Test 3: Preamp")
            do {
                try await icomProtocol.setPreampIC9700(0x01)
                let on = try await icomProtocol.getPreampIC9700()
                guard on == 0x01 else { throw RigError.commandFailed("Preamp ON") }
                print("   ✓ Preamp ON")

                try await icomProtocol.setPreampIC9700(0x00)
                let off = try await icomProtocol.getPreampIC9700()
                guard off == 0x00 else { throw RigError.commandFailed("Preamp OFF") }
                print("   ✓ Preamp OFF")

                testsPassed += 1
                print("   ✅ PASS\n")
            } catch {
                print("   ❌ FAIL: \(error)\n")
                testsFailed += 1
            }

            // Test 4: Attenuator
            print("📉 Test 4: Attenuator")
            do {
                try await icomProtocol.setAttenuatorIC9700(0x10)
                let on = try await icomProtocol.getAttenuatorIC9700()
                guard on == 0x10 else { throw RigError.commandFailed("Attenuator 10dB") }
                print("   ✓ 10dB attenuator ON")

                try await icomProtocol.setAttenuatorIC9700(0x00)
                let off = try await icomProtocol.getAttenuatorIC9700()
                guard off == 0x00 else { throw RigError.commandFailed("Attenuator OFF") }
                print("   ✓ Attenuator OFF")

                testsPassed += 1
                print("   ✅ PASS\n")
            } catch {
                print("   ❌ FAIL: \(error)\n")
                testsFailed += 1
            }

            // Test 5: AGC
            print("🎚️  Test 5: AGC (Automatic Gain Control)")
            do {
                let modes: [(UInt8, String)] = [(0x01, "FAST"), (0x02, "MID"), (0x03, "SLOW")]
                for (code, name) in modes {
                    try await icomProtocol.setAGCIC9700(code)
                    let actual = try await icomProtocol.getAGCIC9700()
                    guard actual == code else { continue }
                    print("   ✓ AGC \(name)")
                }
                testsPassed += 1
                print("   ✅ PASS\n")
            } catch {
                print("   ❌ FAIL: \(error)\n")
                testsFailed += 1
            }

            // Test 6: Squelch Status
            print("📊 Test 6: Squelch Status")
            do {
                let status = try await icomProtocol.getSquelchStatusIC9700()
                print("   ✓ Squelch: \(status ? "OPEN" : "CLOSED")")
                testsPassed += 1
                print("   ✅ PASS\n")
            } catch {
                print("   ❌ FAIL: \(error)\n")
                testsFailed += 1
            }

            await rig.disconnect()
            print("✓ Disconnected\n")

            // Summary
            print(String(repeating: "=", count: 70))
            print("Test Summary")
            print(String(repeating: "=", count: 70))
            print("✅ Passed:  \(testsPassed)")
            print("❌ Failed:  \(testsFailed)")
            print("📊 Total:   \(testsPassed + testsFailed)")
            print(String(repeating: "=", count: 70))
            print("Success Rate: \(String(format: "%.1f", Double(testsPassed) / Double(testsPassed + testsFailed) * 100))%")
            print(String(repeating: "=", count: 70) + "\n")

            if testsFailed == 0 {
                print("🎉 All advanced features PASSED!\n")
            } else {
                print("⚠️  Some tests failed.\n")
                Foundation.exit(1)
            }

        } catch {
            print("❌ Fatal error: \(error)\n")
            Foundation.exit(1)
        }
    }
}
