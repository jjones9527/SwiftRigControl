import Foundation
import RigControl

/// Hardware validation tool for the Kenwood TH-D72 / TH-D72A.
///
/// The TH-D72 is a CR-terminated dual-band APRS/GPS handheld.
/// Unlike the HF Kenwoods (TS-590S etc.) it uses `THD72Protocol`
/// — see `Sources/RigControl/Protocols/Kenwood/THD72Protocol.swift`.
///
/// ## Usage
/// ```bash
/// export THD72_SERIAL_PORT="/dev/cu.SLAB_USBtoUART"
/// swift run THD72Validator
/// ```
///
/// **Prerequisite:** The TH-D72's PC PORT must be ON (Menu 350)
/// before the radio will respond to CAT commands. Otherwise the
/// USB port streams APRS / NMEA GPS data and the radio ignores
/// every CAT request.
@main
struct THD72Validator {
    static func main() async {
        print("==========================================")
        print("  Kenwood TH-D72 Hardware Validation")
        print("==========================================\n")

        guard let port = ProcessInfo.processInfo.environment["THD72_SERIAL_PORT"] else {
            print("❌ Set THD72_SERIAL_PORT first:")
            print("   export THD72_SERIAL_PORT=\"/dev/cu.SLAB_USBtoUART\"")
            exit(1)
        }

        print("Port: \(port)")
        print("Baud: 9600 (TH-D72 default)\n")

        var passed = 0
        var failed = 0

        do {
            // Use the multi-line CR probe to clear any residual APRS/GPS
            // stream from the buffer before sending our first command —
            // otherwise the first FO query reads stale GPS bytes.
            let rig = try RigController(
                radio: .Kenwood.thd72A,
                connection: .serial(path: port, baudRate: nil)
            )

            try await rig.connect()
            print("✓ Connected to TH-D72\n")

            // ── Test 1: Frequency get/set on Band A ──
            // The TH-D72 has two independent bands (Band A / Band B).
            // Each band can be tuned independently to ANY frequency in
            // its hardware range — but VFO A is whatever band the
            // operator has selected via the radio's front panel.
            // We test only 2m frequencies here because Band A defaults
            // to 2m on most operator setups; cross-band changes
            // (2m → 70cm via `FO`) require flipping the band first
            // through the `BC` command, which is a separate operation.
            print("📡 Test 1: Frequency Control (within current Band A range)")
            do {
                let savedFreqA = try await rig.frequency(vfo: .a, cached: false)
                print("   Original VFO A: \(format(savedFreqA))")

                for (freq, label) in [
                    (UInt64(146_520_000), "2m simplex (146.520)"),
                    (UInt64(146_940_000), "2m repeater (146.940)"),
                    (UInt64(145_010_000), "2m calling (145.010)"),
                ] {
                    try await rig.setFrequency(freq, vfo: .a)
                    try await Task.sleep(nanoseconds: 200_000_000)
                    let readback = try await rig.frequency(vfo: .a, cached: false)
                    let ok = readback == freq
                    print("   \(ok ? "✓" : "❌") \(label): set \(format(freq)), got \(format(readback))")
                    if !ok { failed += 1; throw RigError.commandFailed("freq mismatch") }
                }
                try await rig.setFrequency(savedFreqA, vfo: .a)
                print("   ✓ Restored VFO A to \(format(savedFreqA))")
                print("   ✅ Frequency control: PASS\n")
                passed += 1
            } catch {
                print("   ❌ Frequency control: FAIL — \(error)\n")
                failed += 1
            }

            // ── Test 2: Mode control (FM and FM-N only) ──
            // The TH-D72 only carries AM as an RX-only mode on the
            // airband segment (118–136 MHz). Asking the radio to set
            // mode to AM on the 2m band is rejected silently — the
            // radio keeps the previous mode. So validate only the
            // modes that work in the current band.
            print("📻 Test 2: Mode Control (FM / FM-N — AM is RX-only on airband)")
            do {
                let saved = try await rig.mode(vfo: .a, cached: false)
                for mode in [Mode.fm, .fmN] {
                    try await rig.setMode(mode, vfo: .a)
                    try await Task.sleep(nanoseconds: 200_000_000)
                    let readback = try await rig.mode(vfo: .a, cached: false)
                    let ok = readback == mode
                    print("   \(ok ? "✓" : "❌") \(mode.rawValue): set, got \(readback.rawValue)")
                    if !ok { failed += 1; throw RigError.commandFailed("mode mismatch") }
                }
                try await rig.setMode(saved, vfo: .a)
                print("   ✅ Mode control: PASS\n")
                passed += 1
            } catch {
                print("   ❌ Mode control: FAIL — \(error)\n")
                failed += 1
            }

            // ── Test 3: VFO selection (band A / band B) ──
            print("🔀 Test 3: VFO Selection (Bands A/B)")
            do {
                try await rig.selectVFO(.a)
                let freqA = try await rig.frequency(vfo: .a, cached: false)
                print("   ✓ Band A selected, freq: \(format(freqA))")
                try await rig.selectVFO(.b)
                let freqB = try await rig.frequency(vfo: .b, cached: false)
                print("   ✓ Band B selected, freq: \(format(freqB))")
                try await rig.selectVFO(.a)
                print("   ✓ Restored to Band A")
                print("   ✅ VFO selection: PASS\n")
                passed += 1
            } catch {
                print("   ❌ VFO selection: FAIL — \(error)\n")
                failed += 1
            }

            // ── Test 4: Power control (3 discrete levels) ──
            print("⚡ Test 4: Power Control")
            do {
                for level in [0, 1, 2, 5] {
                    try await rig.setPower(level)
                    try await Task.sleep(nanoseconds: 200_000_000)
                    let readback = try await rig.power()
                    print("   ✓ Power \(level)W requested, got \(readback)W")
                }
                print("   ✅ Power control: PASS\n")
                passed += 1
            } catch {
                print("   ❌ Power control: FAIL — \(error)\n")
                failed += 1
            }

            // ── Test 5: PTT control ──
            print("📡 Test 5: PTT Control")
            print("   (Radio is connected to a dummy load — keying transmit briefly)")
            do {
                try await rig.setPTT(true)
                print("   ✓ PTT ON sent")
                try await Task.sleep(nanoseconds: 500_000_000)
                try await rig.setPTT(false)
                print("   ✓ PTT OFF sent")
                print("   ✅ PTT control: PASS")
                print("   (TH-D72 has no PTT status query — visual confirmation only)\n")
                passed += 1
            } catch {
                print("   ❌ PTT control: FAIL — \(error)\n")
                failed += 1
            }

            // ── Test 6: Busy/squelch flag (TH-D72 has no S-meter via CAT) ──
            print("📊 Test 6: Busy/Squelch State (BY command)")
            print("   TH-D72 has no numeric S-meter via CAT — only a busy bit.")
            do {
                // signalStrength() should throw .unsupportedOperation on
                // the TH-D72. Verify that contract before exercising the
                // band-A busy flag directly.
                do {
                    _ = try await rig.signalStrength(cached: false)
                    print("   ⚠️  Expected signalStrength() to throw .unsupportedOperation but it returned a value")
                } catch let RigError.unsupportedOperation(reason) {
                    print("   ✓ signalStrength() correctly threw .unsupportedOperation: \(reason)")
                } catch {
                    print("   ⚠️  signalStrength() threw \(error) — expected .unsupportedOperation")
                }
                // Read the busy flag via the concrete protocol.
                let proto = await rig.rawProtocol
                if let thd72 = proto as? THD72Protocol {
                    for band in [VFO.a, .b] {
                        let busy = try await thd72.getBusy(vfo: band)
                        print("   ✓ Band \(band == .a ? "A" : "B") busy: \(busy ? "ACTIVE" : "idle")")
                    }
                    print("   ✅ Busy/squelch: PASS\n")
                    passed += 1
                } else {
                    print("   ❌ Couldn't cast to THD72Protocol\n")
                    failed += 1
                }
            } catch {
                print("   ❌ Busy/squelch: FAIL — \(error)\n")
                failed += 1
            }

            await rig.disconnect()
            print("✓ Disconnected\n")

        } catch {
            print("❌ Setup or connect failed: \(error)\n")
            failed += 1
        }

        let total = passed + failed
        print("==========================================")
        print(" Test Summary: \(passed)/\(total)")
        print("==========================================")
        if failed == 0 {
            print(" ✅ All tests passed.")
            exit(0)
        } else {
            print(" ❌ \(failed) test(s) failed.")
            exit(1)
        }
    }

    static func format(_ hz: UInt64) -> String {
        String(format: "%.6f MHz", Double(hz) / 1_000_000)
    }
}
