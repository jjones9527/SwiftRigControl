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

    public init() {}

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

        let char = commandChar.first!
        let args = parts.dropFirst().map(String.init)

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

        let args = parts.dropFirst().map(String.init)

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

        // Protocol control
        case "set_ext_response", "set_powerstat":
            guard let enabledStr = args.first else {
                throw ParseError.missingParameter("enabled")
            }
            guard let enabled = Int(enabledStr) else {
                throw ParseError.invalidParameter("enabled", value: enabledStr)
            }
            return .setExtendedResponse(enabled: enabled != 0)

        case "quit", "q":
            return .quit

        default:
            throw ParseError.unknownCommand(String(commandName))
        }
    }
}
