import Foundation

/// Parser for rigctld protocol commands.
///
/// Parses both compact single-character commands and verbose backslash-prefixed long commands.
/// Handles parameter extraction and validation according to rigctld protocol specifications.
///
/// ## Command Formats
///
/// ### Single-Character Commands
/// ```
/// F 14230000        # Set frequency to 14.230 MHz
/// f                 # Get frequency
/// M USB 2400        # Set mode to USB with 2400 Hz passband
/// m                 # Get mode
/// T 1               # Enable PTT
/// t                 # Get PTT status
/// ```
///
/// ### Long Commands (Backslash Prefix)
/// ```
/// \set_freq 14230000
/// \get_freq
/// \set_mode USB 2400
/// \get_mode
/// \set_ptt 1
/// \get_ptt
/// ```
///
/// ## Usage
/// ```swift
/// let parser = RigctldCommandParser()
/// let command = try parser.parse("F 14230000")
/// // Returns: .setFrequency(hz: 14230000)
/// ```
public struct RigctldCommandParser {
    /// Errors that can occur during command parsing
    public enum ParseError: Error, CustomStringConvertible {
        /// Unknown command
        case unknownCommand(String)

        /// Missing required parameter
        case missingParameter(String)

        /// Invalid parameter value
        case invalidParameter(String, value: String)

        /// Malformed command
        case malformedCommand(String)

        public var description: String {
            switch self {
            case .unknownCommand(let cmd):
                return "Unknown command: '\(cmd)'"
            case .missingParameter(let param):
                return "Missing required parameter: \(param)"
            case .invalidParameter(let param, let value):
                return "Invalid value '\(value)' for parameter: \(param)"
            case .malformedCommand(let reason):
                return "Malformed command: \(reason)"
            }
        }
    }

    /// Creates a new parser. Stateless — one shared instance is fine.
    public init() {}

    /// Canonical VFO name strings a client may prepend to any
    /// command that isn't `ARG_NOVFO`, exactly as Hamlib's
    /// `rig_parse_vfo` (`src/misc.c:616`) accepts them.
    /// Case-sensitive per Hamlib: `VFOA` uppercase but `Main` /
    /// `Sub` mixed-case, `currVFO` mixed.
    ///
    /// Deliberately excludes the `"1"` gpredict alias listed at
    /// `misc.c:635`. That alias exists only for `set_vfo 1` (a `V`
    /// command, which takes VFO as its semantic arg and is exempt
    /// from stripping). Including it here would mis-classify the
    /// `1` in bare `T 1` / `S 1` as a VFO prefix, breaking every
    /// non-vfo-opt client. Hamlib itself filters non-alpha VFO
    /// tokens out earlier in `rigctl_parse.c:1442`, so declining
    /// `"1"` here matches real rigctld's effective behavior on the
    /// commands we strip on.
    ///
    /// netrigctl clients send the alpha VFO names when `vfo_opt=1`,
    /// which they enable automatically when the server's
    /// `\dump_state` payload advertises more than one VFO (v1.2.12
    /// does, for any radio with `hasVFOB: true`). Direwolf's
    /// `PTT RIG 2` path is the specific caller flagged by
    /// macwinlink-releases#54.
    private static let vfoNames: Set<String> = [
        "VFOA", "VFOB", "VFOC",
        "currVFO", "VFO",
        "MEM",
        "Main", "MainA", "MainB", "MainC",
        "Sub", "SubA", "SubB", "SubC",
        "TX", "RX",
        "None", "otherVFO", "AllVFOs",
    ]

    /// Short-form command letters whose Hamlib command-table entry
    /// does *not* carry `ARG_NOVFO` — i.e. the ones that accept a
    /// leading canonical VFO argument under `vfo_opt=1`.
    /// Cross-checked against `tests/rigctl_parse.c` lines ~287-352:
    /// F/f, M/m, I/i, X/x, S/s, L/l, U/u, T/t, Y/y. `V`/`v` take
    /// the VFO as their own semantic arg. `b`/`g`/`G` and the
    /// dump/power/probe families are `ARG_NOVFO`.
    private static let shortFormsAcceptingLeadingVFO: Set<Character> = [
        "F", "f", "M", "m", "I", "i", "X", "x", "S", "s",
        "L", "l", "U", "u", "T", "t", "Y", "y",
    ]

    /// Long-form command names whose Hamlib command-table entry
    /// does *not* carry `ARG_NOVFO`. Same rules as the short-form
    /// set, expressed as the `\set_*` / `\get_*` names netrigctl
    /// actually sends over the wire.
    private static let longFormsAcceptingLeadingVFO: Set<String> = [
        "set_freq", "get_freq",
        "set_mode", "get_mode",
        "set_split_freq", "get_split_freq",
        "set_split_mode", "get_split_mode",
        "set_split_vfo", "get_split_vfo",
        "set_level", "get_level",
        "set_func", "get_func",
        "set_ptt", "get_ptt",
        "set_ant", "get_ant",
    ]

    /// If `args.first` matches a canonical Hamlib VFO name, pop it
    /// off and return the token; otherwise leave `args` untouched
    /// and return nil.
    ///
    /// SwiftRigControl's `RigController` operates on a single active
    /// VFO at a time, so the returned token is discarded by callers
    /// — the point of the strip is wire compatibility with clients
    /// that honor the `vfo_opt=1` handshake, not per-VFO routing
    /// inside the library. A future v1.3 could plumb the VFO through
    /// as an optional field on the affected `RigctldCommand` cases.
    private static func stripLeadingVFO(_ args: inout [String]) -> String? {
        guard let first = args.first, vfoNames.contains(first) else { return nil }
        args.removeFirst()
        return first
    }

    /// Parse a command string into a RigctldCommand
    ///
    /// - Parameter input: Command string (e.g., "F 14230000" or "\set_freq 14230000")
    /// - Returns: Parsed command
    /// - Throws: ParseError if command is invalid or malformed
    public func parse(_ input: String) throws -> RigctldCommand {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ParseError.malformedCommand("Empty command")
        }

        // Check if this is a long command (starts with backslash)
        if trimmed.hasPrefix("\\") {
            return try parseLongCommand(String(trimmed.dropFirst()))
        } else {
            return try parseShortCommand(trimmed)
        }
    }

    // MARK: - Short Command Parsing

    private func parseShortCommand(_ input: String) throws -> RigctldCommand {
        let parts = input.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
        guard let commandChar = parts.first, commandChar.count == 1 else {
            throw ParseError.unknownCommand(input)
        }

        guard let char = commandChar.first else {
            throw ParseError.unknownCommand(input)
        }
        var args = parts.dropFirst().map(String.init)

        // Strip a leading canonical VFO name for every command whose
        // Hamlib table entry does NOT set `ARG_NOVFO`
        // (`tests/rigctl_parse.c` command table, lines ~287-352).
        // Clients running `vfo_opt=1` prefix these; netrigctl auto-
        // enables `vfo_opt` when the server's `\dump_state`
        // advertises multiple VFOs, which SwiftRigControl does for
        // any `hasVFOB: true` radio. Not stripping here throws
        // `-1 Invalid parameter` back at the client
        // (macwinlink-releases#54).
        //
        // Excluded (ARG_NOVFO in Hamlib):
        //   V/v (VFO is the semantic arg), b (send_morse), g (scan),
        //   G (vfo_op), and no short forms exist for the
        //   dump_*/set_powerstat/power2mW/mW2power family.
        if Self.shortFormsAcceptingLeadingVFO.contains(char) {
            _ = Self.stripLeadingVFO(&args)
        }

        switch char {
        // Frequency control
        case "F":
            guard let freqStr = args.first else {
                throw ParseError.missingParameter("frequency")
            }
            guard let freq = UInt64(freqStr) else {
                throw ParseError.invalidParameter("frequency", value: freqStr)
            }
            return .setFrequency(hz: freq)

        case "f":
            return .getFrequency

        // Mode control
        case "M":
            guard let mode = args.first else {
                throw ParseError.missingParameter("mode")
            }
            let passband = args.count > 1 ? Int(args[1]) : nil
            return .setMode(mode: mode, passband: passband)

        case "m":
            return .getMode

        // VFO control
        case "V":
            guard let vfo = args.first else {
                throw ParseError.missingParameter("vfo")
            }
            return .setVFO(vfo: vfo)

        case "v":
            return .getVFO

        // PTT control
        case "T":
            guard let pttStr = args.first else {
                throw ParseError.missingParameter("ptt")
            }
            guard let ptt = Int(pttStr) else {
                throw ParseError.invalidParameter("ptt", value: pttStr)
            }
            return .setPTT(enabled: ptt != 0)

        case "t":
            return .getPTT

        // Split control
        case "S":
            guard args.count >= 1 else {
                throw ParseError.missingParameter("split")
            }
            guard let split = Int(args[0]) else {
                throw ParseError.invalidParameter("split", value: args[0])
            }
            let txVFO = args.count > 1 ? args[1] : nil
            return .setSplitVFO(enabled: split != 0, txVFO: txVFO)

        case "s":
            return .getSplitVFO

        case "I":
            guard let freqStr = args.first else {
                throw ParseError.missingParameter("frequency")
            }
            guard let freq = UInt64(freqStr) else {
                throw ParseError.invalidParameter("frequency", value: freqStr)
            }
            return .setSplitFrequency(hz: freq)

        case "i":
            return .getSplitFrequency

        case "X":
            guard let mode = args.first else {
                throw ParseError.missingParameter("mode")
            }
            let passband = args.count > 1 ? Int(args[1]) : nil
            return .setSplitMode(mode: mode, passband: passband)

        case "x":
            return .getSplitMode

        // Power conversion
        case "2":
            guard args.count >= 3 else {
                throw ParseError.missingParameter("power, frequency, mode")
            }
            guard let power = Double(args[0]) else {
                throw ParseError.invalidParameter("power", value: args[0])
            }
            guard let freq = UInt64(args[1]) else {
                throw ParseError.invalidParameter("frequency", value: args[1])
            }
            return .power2mW(power: power, frequency: freq, mode: args[2])

        case "4":
            guard args.count >= 3 else {
                throw ParseError.missingParameter("power, frequency, mode")
            }
            guard let powerMW = Int(args[0]) else {
                throw ParseError.invalidParameter("power", value: args[0])
            }
            guard let freq = UInt64(args[1]) else {
                throw ParseError.invalidParameter("frequency", value: args[1])
            }
            return .mW2power(powerMW: powerMW, frequency: freq, mode: args[2])

        // Level commands
        case "L":
            guard args.count >= 2 else {
                throw ParseError.missingParameter("level name and value")
            }
            return .setLevel(name: args[0], value: args[1])

        case "l":
            guard let name = args.first else {
                throw ParseError.missingParameter("level name")
            }
            return .getLevel(name: name)

        // Quit
        case "q":
            return .quit

        // Function toggles (Phase 4.5) — Hamlib `U`/`u` short forms
        case "U":
            guard args.count >= 2 else {
                throw ParseError.missingParameter("func name and value")
            }
            guard let v = Int(args[1]) else {
                throw ParseError.invalidParameter("func value", value: args[1])
            }
            return .setFunc(name: args[0], enabled: v != 0)

        case "u":
            guard let name = args.first else {
                throw ParseError.missingParameter("func name")
            }
            return .getFunc(name: name)

        // Antenna (Phase 4.5) — Hamlib `Y`/`y` short forms
        case "Y":
            guard let antStr = args.first, let ant = Int(antStr) else {
                throw ParseError.missingParameter("antenna")
            }
            let option = args.count > 1 ? Int(args[1]) : nil
            return .setAntenna(antenna: ant, option: option)

        case "y":
            guard let antStr = args.first, let ant = Int(antStr) else {
                throw ParseError.missingParameter("antenna")
            }
            return .getAntenna(antenna: ant)

        // Scanning (Phase 4.5) — Hamlib `g` short form
        case "g":
            guard let fct = args.first else {
                throw ParseError.missingParameter("scan function")
            }
            let ch = args.count > 1 ? (Int(args[1]) ?? 0) : 0
            return .scan(function: fct, channel: ch)

        // VFO operation (v1.1) — Hamlib `G` short form
        case "G":
            guard let op = args.first else {
                throw ParseError.missingParameter("vfo operation")
            }
            return .vfoOp(op: op)

        // CW send (Phase 4.5) — Hamlib `b` short form takes
        // free-form text. Join all remaining args back with spaces
        // so multi-word messages survive the tokenizer.
        case "b":
            let text = args.joined(separator: " ")
            guard !text.isEmpty else {
                throw ParseError.missingParameter("morse text")
            }
            return .sendMorse(text: text)

        default:
            throw ParseError.unknownCommand(String(char))
        }
    }

    // MARK: - Long Command Parsing

    private func parseLongCommand(_ input: String) throws -> RigctldCommand {
        let parts = input.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
        guard let commandName = parts.first else {
            throw ParseError.malformedCommand("Missing command name")
        }

        var args = parts.dropFirst().map(String.init)

        // Same VFO-strip logic as the short-form parser — real
        // Hamlib rigctld accepts `\set_ptt VFOA 1` etc. under
        // `vfo_opt=1`.
        if Self.longFormsAcceptingLeadingVFO.contains(String(commandName)) {
            _ = Self.stripLeadingVFO(&args)
        }

        switch commandName {
        // Frequency control
        case "set_freq":
            guard let freqStr = args.first else {
                throw ParseError.missingParameter("frequency")
            }
            guard let freq = UInt64(freqStr) else {
                throw ParseError.invalidParameter("frequency", value: freqStr)
            }
            return .setFrequency(hz: freq)

        case "get_freq":
            return .getFrequency

        // Mode control
        case "set_mode":
            guard let mode = args.first else {
                throw ParseError.missingParameter("mode")
            }
            let passband = args.count > 1 ? Int(args[1]) : nil
            return .setMode(mode: mode, passband: passband)

        case "get_mode":
            return .getMode

        // VFO control
        case "set_vfo":
            guard let vfo = args.first else {
                throw ParseError.missingParameter("vfo")
            }
            return .setVFO(vfo: vfo)

        case "get_vfo":
            return .getVFO

        // PTT control
        case "set_ptt":
            guard let pttStr = args.first else {
                throw ParseError.missingParameter("ptt")
            }
            guard let ptt = Int(pttStr) else {
                throw ParseError.invalidParameter("ptt", value: pttStr)
            }
            return .setPTT(enabled: ptt != 0)

        case "get_ptt":
            return .getPTT

        // Split control
        case "set_split_vfo":
            guard args.count >= 1 else {
                throw ParseError.missingParameter("split")
            }
            guard let split = Int(args[0]) else {
                throw ParseError.invalidParameter("split", value: args[0])
            }
            let txVFO = args.count > 1 ? args[1] : nil
            return .setSplitVFO(enabled: split != 0, txVFO: txVFO)

        case "get_split_vfo":
            return .getSplitVFO

        case "set_split_freq":
            guard let freqStr = args.first else {
                throw ParseError.missingParameter("frequency")
            }
            guard let freq = UInt64(freqStr) else {
                throw ParseError.invalidParameter("frequency", value: freqStr)
            }
            return .setSplitFrequency(hz: freq)

        case "get_split_freq":
            return .getSplitFrequency

        case "set_split_mode":
            guard let mode = args.first else {
                throw ParseError.missingParameter("mode")
            }
            let passband = args.count > 1 ? Int(args[1]) : nil
            return .setSplitMode(mode: mode, passband: passband)

        case "get_split_mode":
            return .getSplitMode

        // Power conversion
        case "power2mW":
            guard args.count >= 3 else {
                throw ParseError.missingParameter("power, frequency, mode")
            }
            guard let power = Double(args[0]) else {
                throw ParseError.invalidParameter("power", value: args[0])
            }
            guard let freq = UInt64(args[1]) else {
                throw ParseError.invalidParameter("frequency", value: args[1])
            }
            return .power2mW(power: power, frequency: freq, mode: args[2])

        case "mW2power":
            guard args.count >= 3 else {
                throw ParseError.missingParameter("power, frequency, mode")
            }
            guard let powerMW = Int(args[0]) else {
                throw ParseError.invalidParameter("power", value: args[0])
            }
            guard let freq = UInt64(args[1]) else {
                throw ParseError.invalidParameter("frequency", value: args[1])
            }
            return .mW2power(powerMW: powerMW, frequency: freq, mode: args[2])

        // Level commands
        case "set_level":
            guard args.count >= 2 else {
                throw ParseError.missingParameter("level name and value")
            }
            return .setLevel(name: args[0], value: args[1])

        case "get_level":
            guard let name = args.first else {
                throw ParseError.missingParameter("level name")
            }
            return .getLevel(name: name)

        // Information commands
        case "dump_caps":
            return .dumpCapabilities

        case "dump_state":
            return .dumpState

        case "chk_vfo":
            return .checkVFO

        // Power state control
        case "set_powerstat":
            guard let onStr = args.first else {
                throw ParseError.missingParameter("power state")
            }
            guard let on = Int(onStr) else {
                throw ParseError.invalidParameter("power state", value: onStr)
            }
            return .setPowerStat(on: on != 0)

        case "get_powerstat":
            return .getPowerStat

        // Protocol control
        case "set_ext_response":
            guard let enabledStr = args.first else {
                throw ParseError.missingParameter("enabled")
            }
            guard let enabled = Int(enabledStr) else {
                throw ParseError.invalidParameter("enabled", value: enabledStr)
            }
            return .setExtendedResponse(enabled: enabled != 0)

        case "quit", "q":
            return .quit

        // MARK: Phase 4.5 — function toggles, antenna, scan, CW

        case "set_func":
            guard args.count >= 2 else {
                throw ParseError.missingParameter("func name and value")
            }
            guard let v = Int(args[1]) else {
                throw ParseError.invalidParameter("func value", value: args[1])
            }
            return .setFunc(name: args[0], enabled: v != 0)

        case "get_func":
            guard let name = args.first else {
                throw ParseError.missingParameter("func name")
            }
            return .getFunc(name: name)

        case "set_ant":
            guard let antStr = args.first, let ant = Int(antStr) else {
                throw ParseError.missingParameter("antenna")
            }
            let option = args.count > 1 ? Int(args[1]) : nil
            return .setAntenna(antenna: ant, option: option)

        case "get_ant":
            guard let antStr = args.first, let ant = Int(antStr) else {
                throw ParseError.missingParameter("antenna")
            }
            return .getAntenna(antenna: ant)

        case "scan":
            guard let fct = args.first else {
                throw ParseError.missingParameter("scan function")
            }
            let ch = args.count > 1 ? (Int(args[1]) ?? 0) : 0
            return .scan(function: fct, channel: ch)

        case "vfo_op":
            guard let op = args.first else {
                throw ParseError.missingParameter("vfo operation")
            }
            return .vfoOp(op: op)

        case "send_morse":
            // The args were tokenized on spaces; rejoin to recover
            // multi-word messages like "CQ CQ DE VA3ZTF".
            let text = args.joined(separator: " ")
            guard !text.isEmpty else {
                throw ParseError.missingParameter("morse text")
            }
            return .sendMorse(text: text)

        case "stop_morse":
            return .stopMorse

        default:
            throw ParseError.unknownCommand(String(commandName))
        }
    }
}
