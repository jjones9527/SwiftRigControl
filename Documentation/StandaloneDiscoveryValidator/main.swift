import Foundation
import RigControl

// Standalone SwiftRigControl auto-detection validator.
//
// PURPOSE
// ─────────────────────────────────────────────────────────────
// Validates the v1.1.0 `RadioDiscovery` flow end-to-end against
// real hardware on a machine that doesn't have the SwiftRigControl
// repo cloned. Pulls the library from GitHub via SwiftPM and runs
// the production discovery path.
//
// SETUP (on the machine with the radios)
// ─────────────────────────────────────────────────────────────
//
//   1. Drop Package.swift and main.swift into a fresh directory.
//   2. Plug each radio in one at a time and note its /dev/cu.* path:
//
//        ls /dev/cu.* | grep -v Bluetooth
//
//   3. Export one or more *_SERIAL_PORT env vars for the radios you
//      have connected. The validator picks up whichever are set:
//
//        export IC7100_SERIAL_PORT="/dev/cu.usbserial-AB0NZQ8K"
//        export IC7600_SERIAL_PORT="/dev/cu.SLAB_USBtoUART"
//        export IC9700_SERIAL_PORT="/dev/cu.usbmodem14101"
//        export K2_SERIAL_PORT="/dev/cu.usbserial-FT8XYZWY"
//
//   4. Run:
//
//        swift run --package-path .
//
//      First run takes a minute or two while SPM fetches the package.
//      Subsequent runs are instant.
//
// EXIT CODES
// ─────────────────────────────────────────────────────────────
//   0  — every connected radio was detected on the expected port
//   1  — at least one mismatch or missed detection (see output)

struct Candidate {
    let envKey: String
    let name: String
    let radio: RadioDefinition
}

let candidates: [Candidate] = [
    Candidate(envKey: "IC7100_SERIAL_PORT", name: "Icom IC-7100", radio: .Icom.ic7100()),
    Candidate(envKey: "IC7600_SERIAL_PORT", name: "Icom IC-7600", radio: .Icom.ic7600()),
    Candidate(envKey: "IC9700_SERIAL_PORT", name: "Icom IC-9700", radio: .Icom.ic9700()),
    Candidate(envKey: "K2_SERIAL_PORT",      name: "Elecraft K2", radio: .Elecraft.k2),
]

func format(_ seconds: TimeInterval) -> String {
    String(format: "%.2fs", seconds)
}

@main
struct StandaloneDiscoveryValidator {
    static func main() async {
        print("==========================================")
        print(" SwiftRigControl Standalone Discovery Test")
        print("==========================================\n")

        let env = ProcessInfo.processInfo.environment
        let connected = candidates.filter { env[$0.envKey] != nil }

        guard !connected.isEmpty else {
            print("❌ No *_SERIAL_PORT env vars set. Set at least one of:\n")
            for c in candidates {
                print("   export \(c.envKey)=\"/dev/cu.XXXX\"")
            }
            print("\nThen rerun: swift run --package-path .")
            exit(1)
        }

        print("Radios to probe: \(connected.map(\.name).joined(separator: ", "))\n")

        let enumerator = DefaultSerialPortEnumerator()
        let ports = enumerator.availablePorts()
        print("Available serial ports (in probe priority order):")
        if ports.isEmpty {
            print("  (none — nothing under /dev/cu.* that looks like a radio)")
        }
        for p in ports { print("  \(p)") }
        print()

        var failures = 0

        // ── Single-radio detection ──
        print("── Single-radio detection ────────────────")
        for candidate in connected {
            guard let expected = env[candidate.envKey] else { continue }
            print("\nProbing for \(candidate.name) (expected on \(expected)) ...")

            let start = Date()
            let result = await RadioDiscovery.detect(candidate.radio, timeoutPerPort: 1.5)
            let elapsed = Date().timeIntervalSince(start)

            switch result {
            case let .some(hit):
                if hit.portPath == expected {
                    print("✅ Matched on \(hit.portPath) @ \(hit.baudRate) baud in \(format(elapsed))")
                    print("   identity: \(hit.identityResponse)")
                } else {
                    print("⚠️  Matched on \(hit.portPath) (expected \(expected))")
                    print("   identity: \(hit.identityResponse)")
                    print("   Another radio may be answering, or enumerator ordering put the wrong port first.")
                    failures += 1
                }
            case .none:
                print("❌ Not found (probed \(ports.count) ports in \(format(elapsed)))")
                print("   The radio at \(expected) did not respond to the identify probe.")
                failures += 1
            }
        }

        // ── Multi-radio detection ──
        if connected.count >= 2 {
            print("\n── Multi-radio detection ─────────────────")
            print("Probing for all \(connected.count) candidates in one call ...")

            let start = Date()
            let hits = await RadioDiscovery.detect(connected.map(\.radio), timeoutPerPort: 1.5)
            let elapsed = Date().timeIntervalSince(start)

            print("Found \(hits.count) of \(connected.count) in \(format(elapsed)):")
            for hit in hits {
                let cand = connected.first { $0.radio.fullName == hit.radio.fullName }
                let expected = cand.flatMap { env[$0.envKey] } ?? "—"
                let status = (hit.portPath == expected) ? "✅" : "⚠️ "
                print("  \(status) \(hit.radio.fullName): \(hit.portPath) @ \(hit.baudRate) (expected \(expected))")
            }

            // Port exclusivity: no port should appear twice.
            let portCounts = Dictionary(grouping: hits, by: \.portPath).mapValues(\.count)
            if portCounts.values.contains(where: { $0 > 1 }) {
                print("❌ Port-exclusivity broken: a single port bound to multiple radios.")
                failures += 1
            }
            for candidate in connected {
                let count = hits.filter { $0.radio.fullName == candidate.radio.fullName }.count
                if count == 0 {
                    print("⚠️  \(candidate.name) was not found in the multi-radio sweep.")
                    failures += 1
                } else if count > 1 {
                    print("❌ \(candidate.name) appeared \(count) times in the result list.")
                    failures += 1
                }
            }
        } else {
            print("\n── Multi-radio detection ─────────────────")
            print("Skipped (only one radio connected). Connect a second to exercise this path.")
        }

        // ── Summary ──
        print("\n==========================================")
        if failures == 0 {
            print(" ✅ PASSED — RadioDiscovery works on this hardware.")
            print("==========================================")
            exit(0)
        } else {
            print(" ❌ FAILED — \(failures) issue(s). Capture this output for the issue tracker.")
            print("==========================================")
            exit(1)
        }
    }
}
