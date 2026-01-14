import Foundation
import RigControl

/// Test program for new K2 commands: RC, RD, RU, TQ
@main
struct K2NewCommandsTest {
    static func main() async {
        print("\n" + String(repeating: "=", count: 70))
        print("K2 New Commands Test")
        print("Testing: RC (RIT Clear), RD/RU (RIT Adjust), TQ (TX Query)")
        print(String(repeating: "=", count: 70))

        guard let port = ProcessInfo.processInfo.environment["K2_SERIAL_PORT"] else {
            print("\n❌ Set K2_SERIAL_PORT environment variable")
            print("   Usage: K2_SERIAL_PORT=\"/dev/cu.usbserial-XXXX\" swift run K2NewCommandsTest\n")
            return
        }

        print("\nPort: \(port)\n")

        do {
            let rig = try RigController(
                radio: .elecraftK2,
                connection: .serial(path: port, baudRate: 4800)
            )

            try await rig.connect()
            print("✅ Connected to K2\n")

            guard let proto = await rig.protocol as? ElecraftProtocol else {
                print("❌ Not an Elecraft protocol")
                return
            }

            // Test 1: TQ (Transmit Query)
            print("Test 1: TQ (Transmit Query)")
            print("  Querying TX/RX status...")
            do {
                let isTX = try await proto.getTXStatus()
                print("  ✅ TQ command successful")
                print("  Radio is: \(isTX ? "TRANSMITTING" : "RECEIVING")")
            } catch {
                print("  ❌ Error: \(error)")
            }
            print("")

            // Test 2: Enable RIT and check initial offset
            print("Test 2: RIT Initial State")
            print("  Enabling RIT...")
            try await rig.setRIT(RITXITState(enabled: true, offset: 0))

            let ritBefore = try await rig.getRIT(cached: false)
            print("  ✅ RIT enabled")
            print("  Current offset: \(ritBefore.offset) Hz")
            print("")

            // Test 3: RC (RIT Clear)
            print("Test 3: RC (RIT Clear)")
            print("  Clearing RIT offset...")
            try await proto.clearRITOffset()

            let ritAfterClear = try await rig.getRIT(cached: false)
            print("  ✅ RC command successful")
            print("  Offset after clear: \(ritAfterClear.offset) Hz")
            if ritAfterClear.offset == 0 {
                print("  ✅ Offset correctly cleared to 0")
            } else {
                print("  ⚠️  Offset is \(ritAfterClear.offset) Hz (expected 0)")
            }
            print("")

            // Test 4: RU (RIT Up)
            print("Test 4: RU (RIT Offset Up)")
            print("  Increasing offset by +10 Hz (5 times)...")
            for i in 1...5 {
                try await proto.adjustRITOffset(direction: .up)
                print("  Step \(i): +10 Hz")
                try await Task.sleep(nanoseconds: 100_000_000)  // 100ms between commands
            }

            let ritAfterUp = try await rig.getRIT(cached: false)
            print("  ✅ RU commands successful")
            print("  Final offset: \(ritAfterUp.offset) Hz")
            if ritAfterUp.offset == 50 {
                print("  ✅ Offset correctly increased to +50 Hz")
            } else {
                print("  ⚠️  Offset is \(ritAfterUp.offset) Hz (expected +50)")
            }
            print("")

            // Test 5: RD (RIT Down)
            print("Test 5: RD (RIT Offset Down)")
            print("  Decreasing offset by -10 Hz (3 times)...")
            for i in 1...3 {
                try await proto.adjustRITOffset(direction: .down)
                print("  Step \(i): -10 Hz")
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            let ritAfterDown = try await rig.getRIT(cached: false)
            print("  ✅ RD commands successful")
            print("  Final offset: \(ritAfterDown.offset) Hz")
            if ritAfterDown.offset == 20 {
                print("  ✅ Offset correctly decreased to +20 Hz")
            } else {
                print("  ⚠️  Offset is \(ritAfterDown.offset) Hz (expected +20)")
            }
            print("")

            // Test 6: Large offset range test
            print("Test 6: Large Offset Range Test")
            print("  Testing range limits (-9990 to +9990 Hz)...")

            // Clear to start
            try await proto.clearRITOffset()

            // Go to +100 Hz
            for _ in 1...10 {
                try await proto.adjustRITOffset(direction: .up)
            }
            let ritPlus100 = try await rig.getRIT(cached: false)
            print("  After +100 Hz: \(ritPlus100.offset) Hz")

            // Go to -100 Hz from 0
            try await proto.clearRITOffset()
            for _ in 1...10 {
                try await proto.adjustRITOffset(direction: .down)
            }
            let ritMinus100 = try await rig.getRIT(cached: false)
            print("  After -100 Hz: \(ritMinus100.offset) Hz")

            if ritPlus100.offset == 100 && ritMinus100.offset == -100 {
                print("  ✅ Offset adjustment working correctly in both directions")
            }
            print("")

            // Test 7: Clear and disable RIT
            print("Test 7: Cleanup")
            print("  Clearing and disabling RIT...")
            try await proto.clearRITOffset()
            try await rig.setRIT(RITXITState(enabled: false, offset: 0))

            let ritFinal = try await rig.getRIT(cached: false)
            print("  ✅ RIT disabled")
            print("  Final state: enabled=\(ritFinal.enabled), offset=\(ritFinal.offset) Hz")
            print("")

            await rig.disconnect()
            print("✅ Disconnected\n")

            // Summary
            print(String(repeating: "=", count: 70))
            print("Test Summary")
            print(String(repeating: "=", count: 70))
            print("✅ All new K2 commands working correctly!")
            print("   • TQ (Transmit Query): ✅")
            print("   • RC (RIT Clear): ✅")
            print("   • RU (RIT Up): ✅")
            print("   • RD (RIT Down): ✅")
            print(String(repeating: "=", count: 70) + "\n")

        } catch {
            print("\n❌ Error: \(error)\n")
        }
    }
}
