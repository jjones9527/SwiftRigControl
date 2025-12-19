import Foundation

/// Rigctld protocol definitions and command types.
///
/// The rigctld protocol is Hamlib's TCP-based rig control protocol, allowing remote
/// control of radio transceivers over a network connection. It supports two protocol modes:
/// - **Default Protocol**: Simple, minimal responses for machine-to-machine communication
/// - **Extended Response Protocol**: Verbose responses with command echo and return codes
///
/// ## Protocol Modes
///
/// ### Default Protocol
/// Commands are sent as single characters or long names prefixed with backslash.
/// Responses are minimal, containing only the requested data.
///
/// Example:
/// ```
/// Client: f\n
/// Server: 14230000\n
/// ```
///
/// ### Extended Response Protocol
/// Commands are echoed back with their long names, followed by response data,
/// and terminated with a return code (RPRT x).
///
/// Example:
/// ```
/// Client: \get_freq\n
/// Server: get_freq: 14230000\n
/// Server: RPRT 0\n
/// ```
public enum RigctldProtocol {
    /// Default TCP port for rigctld (Hamlib standard)
    public static let defaultPort: UInt16 = 4532

    /// Protocol response modes
    public enum ResponseMode {
        /// Default protocol - minimal responses
        case `default`

        /// Extended response protocol - verbose with return codes
        case extended
    }

    /// Return codes for extended protocol responses
    public enum ReturnCode: Int, Sendable {
        /// Command succeeded
        case ok = 0

        /// Invalid parameter
        case invalidParam = -1

        /// Invalid configuration
        case invalidConfig = -2

        /// Out of memory
        case outOfMemory = -3

        /// Feature not implemented
        case notImplemented = -4

        /// Communication error
        case communicationError = -5

        /// Timeout
        case timeout = -6

        /// I/O error
        case ioError = -7

        /// Internal error
        case internalError = -8

        /// Protocol error
        case protocolError = -9

        /// Command rejected
        case rejected = -10

        /// Argument error
        case argumentError = -11

        /// Not supported
        case notSupported = -12

        /// VFO not targetable
        case vfoNotTargetable = -13

        /// Error getting/setting
        case error = -14

        var description: String {
            "RPRT \(rawValue)"
        }
    }
}

/// Rigctld command types
///
/// Maps both single-character and long command names to unified command types.
/// This enables parsing of both compact and verbose command formats.
public enum RigctldCommand: Sendable, Equatable {
    // MARK: - Frequency Control

    /// Set frequency (F or \set_freq)
    case setFrequency(hz: UInt64)

    /// Get frequency (f or \get_freq)
    case getFrequency

    // MARK: - Mode Control

    /// Set mode (M or \set_mode)
    case setMode(mode: String, passband: Int?)

    /// Get mode (m or \get_mode)
    case getMode

    // MARK: - VFO Control

    /// Set VFO (V or \set_vfo)
    case setVFO(vfo: String)

    /// Get VFO (v or \get_vfo)
    case getVFO

    // MARK: - PTT Control

    /// Set PTT (T or \set_ptt)
    case setPTT(enabled: Bool)

    /// Get PTT (t or \get_ptt)
    case getPTT

    // MARK: - Split Operation

    /// Set split VFO (S or \set_split_vfo)
    case setSplitVFO(enabled: Bool, txVFO: String?)

    /// Get split VFO (s or \get_split_vfo)
    case getSplitVFO

    /// Set split frequency (I or \set_split_freq)
    case setSplitFrequency(hz: UInt64)

    /// Get split frequency (i or \get_split_freq)
    case getSplitFrequency

    /// Set split mode (X or \set_split_mode)
    case setSplitMode(mode: String, passband: Int?)

    /// Get split mode (x or \get_split_mode)
    case getSplitMode

    // MARK: - Power Control

    /// Convert power to milliwatts (2 or \power2mW)
    case power2mW(power: Double, frequency: UInt64, mode: String)

    /// Convert milliwatts to power (4 or \mW2power)
    case mW2power(powerMW: Int, frequency: UInt64, mode: String)

    // MARK: - Level Commands

    /// Set level (L or \set_level)
    /// Currently supports AGC level
    case setLevel(name: String, value: String)

    /// Get level (l or \get_level)
    /// Currently supports AGC level
    case getLevel(name: String)

    // MARK: - Information Commands

    /// Dump radio capabilities (\dump_caps)
    case dumpCapabilities

    /// Dump current state (\dump_state)
    case dumpState

    /// Check VFO mode (\chk_vfo)
    case checkVFO

    // MARK: - Protocol Control

    /// Set extended response protocol (\set_powerstat or protocol extension)
    case setExtendedResponse(enabled: Bool)

    /// Quit connection (q or \quit)
    case quit

    /// Long command name for the command
    var longName: String {
        switch self {
        case .setFrequency: return "set_freq"
        case .getFrequency: return "get_freq"
        case .setMode: return "set_mode"
        case .getMode: return "get_mode"
        case .setVFO: return "set_vfo"
        case .getVFO: return "get_vfo"
        case .setPTT: return "set_ptt"
        case .getPTT: return "get_ptt"
        case .setSplitVFO: return "set_split_vfo"
        case .getSplitVFO: return "get_split_vfo"
        case .setSplitFrequency: return "set_split_freq"
        case .getSplitFrequency: return "get_split_freq"
        case .setSplitMode: return "set_split_mode"
        case .getSplitMode: return "get_split_mode"
        case .power2mW: return "power2mW"
        case .mW2power: return "mW2power"
        case .setLevel: return "set_level"
        case .getLevel: return "get_level"
        case .dumpCapabilities: return "dump_caps"
        case .dumpState: return "dump_state"
        case .checkVFO: return "chk_vfo"
        case .setExtendedResponse: return "set_ext_response"
        case .quit: return "quit"
        }
    }
}
