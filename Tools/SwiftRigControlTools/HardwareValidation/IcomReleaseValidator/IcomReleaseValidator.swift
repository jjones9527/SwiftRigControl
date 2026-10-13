import Foundation
import RigControl
import ValidationHelpers

/// Hardware check for the v1.2.16-v1.2.19 Icom changes, which were
/// mock-tested only when they shipped.
///
/// | Check                    | Release | What changed |
/// |--------------------------|---------|--------------|
/// | Exclusive port access    | 1.2.18  | `IOKitSerialPort.open()` sets `TIOCEXCL` |
/// | DATA-mode set / readback | 1.2.19  | DATA flag set and read with `0x1A 0x06` |
/// | Front-panel DATA readback| 1.2.19  | `getMode` reads the radio's real DATA flag |
/// | AGC round trip           | 1.2.17  | Per-model Hamlib `agc_levels` wire bytes |
/// | Power-state probe        | 1.2.10  | Probe goes through `getFrequency(vfo: .a)` |
/// | PTT (opt-in, keys TX)    | 1.2.16  | Async-frame skip in the receive loop |
///
/// ## Usage
/// ```bash
/// cd Tools/SwiftRigControlTools
/// swift run IcomReleaseValidator ic7100 /dev/cu.usbserial-XXXX
/// swift run IcomReleaseValidator ic7600 /dev/cu.usbserial-XXXX
/// swift run IcomReleaseValidator ic9700 /dev/cu.usbserial-XXXX
/// ```
/// Add `--no-prompt` to skip the front-panel and PTT steps.
///
/// The radio's frequency, mode and AGC are restored at the end.
@main
struct IcomReleaseValidator {

    struct Target {
        let name: String
        let radio: RadioDefinition
        /// Frequencies for the SSB and FM mode checks.
        let ssbFrequency: UInt64
        let fmFrequency: UInt64
    }

    static func target(_ key: String) -> Target? {
        switch key.lowercased().replacingOccurrences(of: "-", with: "") {
        case "ic7100", "7100":
            return Target(name: "IC-7100", radio: .Icom.ic7100(),
                          ssbFrequency: 14_074_000, fmFrequency: 145_500_000)
        case "ic7600", "7600":
            return Target(name: "IC-7600", radio: .Icom.ic7600(),
                          ssbFrequency: 14_074_000, fmFrequency: 29_600_000)
        case "ic9700", "9700":
            return Target(name: "IC-9700", radio: .Icom.ic9700(),
                          ssbFrequency: 144_174_000, fmFrequency: 145_500_000)
        default:
            return nil
        }
    }

    static func main() async {
        let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
        let prompts = !CommandLine.arguments.contains("--no-prompt")

        guard args.count == 2, let target = target(args[args.startIndex]) else {
            print("Usage: swift run IcomReleaseValidator <ic7100|ic7600|ic9700> <serial-port> [--no-prompt]")
            let ports = ValidationHelpers.listSerialPorts()
            if !ports.isEmpty {
                print("\nAvailable serial ports:")
                ports.forEach { print("  \($0)") }
            }
            Foundation.exit(2)
        }
        let port = args[args.index(after: args.startIndex)]

        ValidationHelpers.printHeader("\(target.name) release check (v1.2.16-v1.2.19)")
        print("  Port: \(port)")
        print("  Prompts: \(prompts ? "on" : "off (--no-prompt)")\n")

        var report = ValidationHelpers.TestReport()

        do {
            let rig = try RigController(radio: target.radio,
                                        connection: .serial(path: port, baudRate: nil))
            try await rig.connect()
            ValidationHelpers.printSuccess("Connected to \(target.name)")

            print("\n💾 Saving radio state...")
            let saved = try await ValidationHelpers.RadioState.save(from: rig)
            saved.print()
            let savedAGC = try? await rig.agc(cached: false)

            await checkExclusiveAccess(port: port, report: &report)
            await checkDataModes(rig: rig, target: target, report: &report)
            if prompts {
                await checkFrontPanelDataReadback(rig: rig, target: target, report: &report)
            } else {
                report.recordSkip("Front-panel DATA readback")
            }
            await checkAGC(rig: rig, report: &report)
            await checkPowerState(rig: rig, report: &report)
            if prompts {
                await checkPTT(rig: rig, target: target, report: &report)
            } else {
                report.recordSkip("PTT")
            }

            print("\n🔄 Restoring original radio state...")
            try await saved.restore(to: rig)
            if let savedAGC { try? await rig.setAGC(savedAGC) }
            ValidationHelpers.printSuccess("Radio state restored")

            await rig.disconnect()
            report.printSummary(radioName: target.name)
            Foundation.exit(report.exitCode)
        } catch {
            ValidationHelpers.printError("Fatal error: \(error)")
            Foundation.exit(1)
        }
    }

    // MARK: - Checks

    /// v1.2.18: a second open of the same port must fail while we hold it.
    static func checkExclusiveAccess(port: String, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Exclusive port access (TIOCEXCL)", icon: "🔒")
        let second = IOKitSerialPort(configuration: SerialConfiguration(path: port, baudRate: 19200))
        do {
            try await second.open()
            await second.close()
            report.recordFailure("Exclusive port access", error: "a second open of \(port) succeeded")
            ValidationHelpers.printError("A second open succeeded; another program could share the port\n")
        } catch {
            report.recordPass()
            ValidationHelpers.printSuccess("Second open refused: \(error)\n")
        }
    }

    /// v1.2.19: set each mode and read it back. The voice mode after each
    /// DATA mode checks that the DATA flag is cleared again.
    static func checkDataModes(rig: RigController, target: Target,
                               report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("DATA-mode set and readback", icon: "📻")
        let supported = Set(await rig.capabilities.supportedModes)

        let sequences: [(UInt64, [Mode])] = [
            (target.ssbFrequency, [.usb, .dataUSB, .usb, .lsb, .dataLSB, .lsb, .dataUSB, .cw]),
            (target.fmFrequency, [.fm, .dataFM, .fm]),
        ]

        for (frequency, modes) in sequences {
            let modes = modes.filter(supported.contains)
            guard !modes.isEmpty else { continue }
            do {
                try await rig.setFrequency(frequency, vfo: .a)
                ValidationHelpers.printInfo("At \(ValidationHelpers.formatFrequency(frequency))")
            } catch {
                report.recordFailure("Set \(ValidationHelpers.formatFrequency(frequency))",
                                     error: "\(error)")
                ValidationHelpers.printError("Could not tune: \(error)")
                continue
            }
            var previous: Mode?
            for mode in modes {
                let name = previous.map { "\($0.rawValue) → \(mode.rawValue)" } ?? mode.rawValue
                do {
                    try await rig.setMode(mode, vfo: .a)
                    let actual = try await rig.mode(vfo: .a, cached: false)
                    if actual == mode {
                        report.recordPass()
                        ValidationHelpers.printSuccess("\(name): reads \(actual.rawValue)")
                    } else {
                        report.recordFailure("Mode \(name)", error: "read back \(actual.rawValue)")
                        ValidationHelpers.printError("\(name): read back \(actual.rawValue)")
                    }
                } catch {
                    report.recordFailure("Mode \(name)", error: "\(error)")
                    ValidationHelpers.printError("\(name): \(error)")
                }
                previous = mode
            }
        }
        print()
    }

    /// v1.2.19: the DATA flag set from the front panel, not by us, reads
    /// back. Before v1.2.19 this always read as plain USB.
    static func checkFrontPanelDataReadback(rig: RigController, target: Target,
                                            report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Front-panel DATA readback", icon: "🖐")
        do {
            try await rig.setFrequency(target.ssbFrequency, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)
        } catch {
            report.recordFailure("Front-panel DATA readback", error: "setup: \(error)")
            return
        }

        let steps: [(String, Mode)] = [
            ("Turn DATA ON from the front panel (USB-D / USB DATA)", .dataUSB),
            ("Turn DATA OFF from the front panel (plain USB)", .usb),
        ]
        for (instruction, expected) in steps {
            print("   → \(instruction), then press Enter (s to skip): ", terminator: "")
            fflush(stdout)
            if readLine()?.lowercased() == "s" {
                report.recordSkip("Front-panel \(expected.rawValue)")
                continue
            }
            do {
                let actual = try await rig.mode(vfo: .a, cached: false)
                if actual == expected {
                    report.recordPass()
                    ValidationHelpers.printSuccess("Reads \(actual.rawValue)")
                } else {
                    report.recordFailure("Front-panel \(expected.rawValue)",
                                         error: "read \(actual.rawValue)")
                    ValidationHelpers.printError("Expected \(expected.rawValue), read \(actual.rawValue)")
                }
            } catch {
                report.recordFailure("Front-panel \(expected.rawValue)", error: "\(error)")
                ValidationHelpers.printError("\(error)")
            }
        }
        print()
    }

    /// v1.2.17: AGC wire bytes come from each model's Hamlib table.
    /// Check the radio's AGC display matches each step.
    static func checkAGC(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("AGC round trip (check the radio's AGC display)", icon: "🎚")
        for speed in [AGCSpeed.fast, .medium, .slow] {
            do {
                try await rig.setAGC(speed)
                let actual = try await rig.agc(cached: false)
                if actual == speed {
                    report.recordPass()
                    ValidationHelpers.printSuccess("\(speed.rawValue): reads \(actual.rawValue)")
                } else {
                    report.recordFailure("AGC \(speed.rawValue)", error: "read back \(actual.rawValue)")
                    ValidationHelpers.printError("\(speed.rawValue): read back \(actual.rawValue)")
                }
            } catch {
                report.recordFailure("AGC \(speed.rawValue)", error: "\(error)")
                ValidationHelpers.printError("\(speed.rawValue): \(error)")
            }
        }
        print()
    }

    /// v1.2.10: the power-state probe on a radio that is on.
    static func checkPowerState(rig: RigController, report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("Power-state probe", icon: "🔌")
        do {
            if try await rig.getPowerState() {
                report.recordPass()
                ValidationHelpers.printSuccess("Reports on\n")
            } else {
                report.recordFailure("Power-state probe", error: "reported off")
                ValidationHelpers.printError("Reported off\n")
            }
        } catch {
            report.recordFailure("Power-state probe", error: "\(error)")
            ValidationHelpers.printError("\(error)\n")
        }
    }

    /// v1.2.16: PTT ACKs arrive even with transceive broadcasts on the
    /// bus. Keys the transmitter three times for about a second each.
    static func checkPTT(rig: RigController, target: Target,
                        report: inout ValidationHelpers.TestReport) async {
        ValidationHelpers.printTestSection("PTT with async-frame skip", icon: "🎙")
        let power = (try? await rig.power()) ?? 0
        guard ValidationHelpers.confirmPTTTest(radioName: target.name,
                                               frequency: target.ssbFrequency,
                                               power: power) else {
            report.recordSkip("PTT")
            return
        }
        do {
            try await rig.setFrequency(target.ssbFrequency, vfo: .a)
            for cycle in 1...3 {
                try await rig.setPTT(true)
                let keyed = try await rig.isPTTEnabled()
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await rig.setPTT(false)
                let unkeyed = try await rig.isPTTEnabled()
                guard keyed, !unkeyed else {
                    report.recordFailure("PTT cycle \(cycle)",
                                         error: "keyed=\(keyed), still keyed after release=\(unkeyed)")
                    ValidationHelpers.printError("Cycle \(cycle): keyed=\(keyed), after unkey=\(unkeyed)")
                    return
                }
                ValidationHelpers.printSuccess("Cycle \(cycle): keyed and released")
            }
            report.recordPass()
        } catch {
            try? await rig.setPTT(false)
            report.recordFailure("PTT", error: "\(error)")
            ValidationHelpers.printError("\(error)")
        }
        print()
    }
}
