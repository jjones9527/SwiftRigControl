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
    /// Supports: AF, RF, SQL, PREAMP, ATT, RFPOWER, AGC, NB, NR,
    /// IF/IFFILTER, KEYSPD, CWPITCH.
    case setLevel(name: String, value: String)

    /// Get level (l or \get_level)
    /// Supports: AF, RF, SQL, PREAMP, ATT, RFPOWER, AGC, NB, NR,
    /// IF/IFFILTER, KEYSPD, CWPITCH, SWR, ALC, RFPOWER_METER,
    /// RFPOWER_METER_WATTS, COMP_METER, VD_METER, ID_METER.
    case getLevel(name: String)

    // MARK: - Function toggles (Phase 4.5)

    /// Set a function bit (`U` or `\set_func`). SwiftRigControl
    /// currently supports `SBKIN` (semi break-in on/off) and
    /// `FBKIN` (full break-in on/off). Other Hamlib function bits
    /// return `.notImplemented`.
    case setFunc(name: String, enabled: Bool)

    /// Get a function bit (`u` or `\get_func`). See `setFunc`
    /// for the supported names.
    case getFunc(name: String)

    // MARK: - Antenna (Phase 4.5)

    /// Set antenna (`Y` or `\set_ant`). The Hamlib signature is
    /// `set_ant <Antenna> [<Option>]`; the optional second
    /// argument carries per-radio quirks (RX-only routing) that
    /// SwiftRigControl does not yet model.
    case setAntenna(antenna: Int, option: Int?)

    /// Get antenna (`y` or `\get_ant`). The Hamlib signature is
    /// `get_ant <Antenna>` returning four fields; the input
    /// `antenna` acts as a hint to the radio when there are
    /// RX-only antennas.
    case getAntenna(antenna: Int)

    // MARK: - Scanning (Phase 4.5)

    /// Start/stop a scan (`g` or `\scan`). Format: `scan <fct>
    /// <ch>`. `fct` is one of VFO / MEM / SLCT / PRIO / PROG /
    /// DELTA / STOP. `ch` (scan-channel hint) is parsed but
    /// ignored — `CATProtocol.startScan(_:)` doesn't model it.
    case scan(function: String, channel: Int)

    // MARK: - VFO operations (v1.1 parity)

    /// Perform a compound VFO operation (`G` or `\vfo_op`).
    /// `op` is the Hamlib token: CPY, XCHG, FROM_VFO, TO_VFO,
    /// MCL, UP, DOWN, BAND_UP, BAND_DOWN, TUNE, TOGGLE.
    case vfoOp(op: String)

    // MARK: - CW (Phase 4.5)

    /// Send a CW message (`b` or `\send_morse`).
    case sendMorse(text: String)

    /// Abort any CW message in flight (`\stop_morse`).
    case stopMorse

    // MARK: - Information Commands

    /// Dump radio capabilities (\dump_caps)
    case dumpCapabilities

    /// Dump current state (\dump_state)
    case dumpState

    /// Check VFO mode (\chk_vfo)
    case checkVFO

    // MARK: - Power State

    /// Set power state (\set_powerstat) — remote on/off
    case setPowerStat(on: Bool)

    /// Get power state (\get_powerstat)
    case getPowerStat

    // MARK: - Protocol Control

    /// Set extended response protocol (\set_ext_response)
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
        case .setFunc: return "set_func"
        case .getFunc: return "get_func"
        case .setAntenna: return "set_ant"
        case .getAntenna: return "get_ant"
        case .scan: return "scan"
        case .vfoOp: return "vfo_op"
        case .sendMorse: return "send_morse"
        case .stopMorse: return "stop_morse"
        case .setPowerStat: return "set_powerstat"
        case .getPowerStat: return "get_powerstat"
        case .dumpCapabilities: return "dump_caps"
        case .dumpState: return "dump_state"
        case .checkVFO: return "chk_vfo"
        case .setExtendedResponse: return "set_ext_response"
        case .quit: return "quit"
        }
    }
}
