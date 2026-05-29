import Foundation
import RigControl

/// Hardware validator for ``RadioDiscovery``.
///
/// Drives the production discovery path against every radio whose
/// `*_SERIAL_PORT` env var is set, then verifies that the matched
/// port equals the expected one. Also exercises the multi-radio
/// overload if two or more radios are connected.
///
/// ## Usage
///
/// Plug each radio in and export its port:
///
/// ```bash
/// export IC7100_SERIAL_PORT="/dev/cu.usbserial-XXXX"
/// export IC7600_SERIAL_PORT="/dev/cu.SLAB_USBtoUART"
/// export IC9700_SERIAL_PORT="/dev/cu.usbmodem14101"
/// export K2_SERIAL_PORT="/dev/cu.usbserial-FT8XYZ"
/// swift run RadioDiscoveryValidator
/// ```
///
/// At least one `*_SERIAL_PORT` env var must be set or the
/// validator exits non-zero with usage.
@main
struct RadioDiscoveryValidator {

    /// One radio under test: the expected port, the radio definition,
    /// and a human-readable name.
    struct Candidate {
        let envKey: String
        let name: String
        let radio: RadioDefinition
    }

    static func main() async {
        print("======================================")
        print(" RadioDiscovery Hardware Validator")
        print("======================================\n")

        let candidates: [Candidate] = [
            Candidate(envKey: "IC7100_SERIAL_PORT", name: "Icom IC-7100", radio: .Icom.ic7100()),
            Candidate(envKey: "IC7600_SERIAL_PORT", name: "Icom IC-7600", radio: .Icom.ic7600()),
            Candidate(envKey: "IC9700_SERIAL_PORT", name: "Icom IC-9700", radio: .Icom.ic9700()),
            Candidate(envKey: "K2_SERIAL_PORT",      name: "Elecraft K2", radio: .Elecraft.k2),
        ]

        let env = ProcessInfo.processInfo.environment
        let connected = candidates.filter { env[$0.envKey] != nil }

        guard !connected.isEmpty else {
            print("❌ No *_SERIAL_PORT env vars set. Set at least one of:")
            for c in candidates {
                print("   export \(c.envKey)=\"/dev/cu.XXXX\"")
            }
            exit(1)
        }

        print("Radios to test: \(connected.map(\.name).joined(separator: ", "))\n")

        // List the ports the production enumerator currently sees.
        let enumerator = DefaultSerialPortEnumerator()
        let ports = enumerator.availablePorts()
        print("Available serial ports (in probe priority order):")
        for p in ports { print("  \(p)") }
        print()

        var failures = 0

        // MARK: - Single-radio detection

        print("── Single-radio detection ────────────────")
        for candidate in connected {
            guard let expectedPort = env[candidate.envKey] else { continue }
            print("\nProbing for \(candidate.name) (expected on \(expectedPort)) ...")

            let start = Date()
            let result = await RadioDiscovery.detect(candidate.radio, timeoutPerPort: 1.5)
            let elapsed = Date().timeIntervalSince(start)

            switch result {
            case let .some(hit):
                if hit.portPath == expectedPort {
                    print("✅ Matched on \(hit.portPath) @ \(hit.baudRate) baud in \(format(elapsed))")
                    print("   identity: \(hit.identityResponse)")
                } else {
                    print("⚠️  Matched on \(hit.portPath) (expected \(expectedPort))")
                    print("   identity: \(hit.identityResponse)")
                    print("   This is a false positive — another radio answered on the wrong port,")
                    print("   or the enumerator ordering moved the wrong port first.")
                    failures += 1
                }
            case .none:
                print("❌ Not found (probed \(ports.count) ports in \(format(elapsed)))")
                print("   The radio at \(expectedPort) did not respond to the identify probe.")
                failures += 1
            }
        }

        // MARK: - Multi-radio detection

        if connected.count >= 2 {
            print("\n── Multi-radio detection ─────────────────")
            print("Probing for all \(connected.count) candidates in one call ...")

            let start = Date()
            let hits = await RadioDiscovery.detect(connected.map(\.radio), timeoutPerPort: 1.5)
            let elapsed = Date().timeIntervalSince(start)

            print("Found \(hits.count) of \(connected.count) in \(format(elapsed)):")
            for hit in hits {
                let candidate = connected.first { $0.radio.fullName == hit.radio.fullName }
                let expectedPort = candidate.flatMap { env[$0.envKey] } ?? "—"
                let status = (hit.portPath == expectedPort) ? "✅" : "⚠️ "
                print("  \(status) \(hit.radio.fullName): \(hit.portPath) @ \(hit.baudRate) (expected \(expectedPort))")
            }
            // Check exclusivity: no port should appear twice.
            let portCounts = Dictionary(grouping: hits, by: \.portPath).mapValues(\.count)
            if portCounts.values.contains(where: { $0 > 1 }) {
                print("❌ Port-exclusivity broken: a single port was bound to multiple radios.")
                failures += 1
            }
            // Each connected radio with a matching env var should appear exactly once.
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

        // MARK: - Summary

        print("\n======================================")
        if failures == 0 {
            print(" ✅ PASSED — RadioDiscovery works on this hardware.")
            print("======================================")
            exit(0)
        } else {
            print(" ❌ FAILED — \(failures) issue(s). Capture this output and file an issue.")
            print("======================================")
            exit(1)
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        String(format: "%.2fs", seconds)
    }
}
