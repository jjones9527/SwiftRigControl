import Foundation

/// Protocol defining radio-specific CI-V command formatting.
///
/// Different Icom radio models use slightly different CI-V command formats
/// for the same operations. This protocol allows each radio to define its
/// own command formatting and response parsing while keeping the core
/// CI-V transport and frame structure common.
///
/// ## Key Differences Between Radios
/// - **Mode commands**: Some require filter byte (IC-9700), others don't (IC-7100)
/// - **Power units**: Some use percentage (IC-7100), others use watts (IC-9700)
/// - **VFO selection**: Some require explicit selection, others don't
/// - **Command echo**: Some radios echo commands before responding (IC-7100, IC-705)
///
/// ## Example Usage
/// ```swift
/// let commandSet = IC7100CommandSet()
/// let (cmd, data) = commandSet.setPowerCommand(value: 50)
/// // Returns ([0x14, 0x0A], BCD bytes for 50%)
/// ```
public protocol CIVCommandSet: Sendable {
    /// Radio's CI-V address (e.g., 0x88 for IC-7100)
    var civAddress: UInt8 { get }

    /// Power units used by this radio (percentage or watts)
    var powerUnits: PowerUnits { get }

    /// Whether radio echoes commands before sending response
    /// IC-7100 and IC-705 echo commands, most others don't
    var echoesCommands: Bool { get }

    /// Whether this radio requires explicit VFO selection before frequency/mode changes
    var requiresVFOSelection: Bool { get }

    // MARK: - Mode Commands

    /// Format a mode set command for normal (non-data) modes.
    /// - Parameter mode: The operating mode code to set (e.g., 0x00 for LSB)
    /// - Returns: Command bytes and data bytes
    func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8])

    /// Format a mode set command for DATA modes (DATA-USB, DATA-LSB, DATA-FM).
    ///
    /// On targetable radios uses `C_SEND_SEL_MODE (0x26)` with explicit data-flag byte (Hamlib approach).
    /// On non-targetable radios falls back to `C_SET_MODE (0x06)` with filter byte `0x00`.
    /// - Parameter mode: The base mode code (e.g., `0x01` for USB → DATA-USB)
    /// - Returns: Command bytes and data bytes
    func setDataModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8])

    /// Whether this radio needs the protocol to send a separate
    /// `0x1A 0x06 [data_flag, filter]` frame after the base
    /// mode set in order to enter or leave a DATA sub-mode.
    ///
    /// Every modern Icom that supports DATA modes but doesn't use
    /// `0x26` (IC-7600, IC-7700, IC-9100, IC-9700, IC-7100, IC-705, …)
    /// needs this — the base mode command only sets USB/LSB/FM; the
    /// second frame flips the DATA sub-mode bit. `getMode` reads the
    /// flag back with `0x1A 0x06`.
    ///
    /// The `0x26` radios (IC-7300, IC-7300MK2) return `false` because
    /// their mode frame already carries the data flag inline.
    var requiresDataModeSubCommand: Bool { get }

    /// Whether `setMode` / `getMode` use `0x26` (`C_SEND_SEL_MODE`),
    /// which carries mode, DATA flag and filter in one frame.
    ///
    /// When `true`, every mode set is `0x26 [0x00, mode, data, filter]`
    /// and reads are `0x26 [0x00]`. If the radio NAKs `0x26`,
    /// `IcomCIVProtocol` falls back to `0x06` + `0x1A 0x06` for the rest
    /// of the connection. See
    /// ``IcomRadioCommandSet/acceptsSelectedVFOModeCommand``.
    var usesSelectedVFOModeCommand: Bool { get }

    /// Whether `IcomCIVProtocol.sendFrame` must flush the
    /// transport's input buffer before writing each frame.
    ///
    /// Required on radios (currently IC-7100 / IC-705) that
    /// share their USB endpoint between async transceive
    /// notifications and CAT command replies. See
    /// ``IcomRadioCommandSet/requiresPreTransactionFlush`` for
    /// the Hamlib citation and full rationale.
    ///
    /// Declared here at the base-protocol level so
    /// `IcomCIVProtocol`'s existential (`any CIVCommandSet`)
    /// dispatches dynamically to the concrete conformance.  A
    /// pure protocol-extension default would resolve to the
    /// base's `false` at compile time and defeat the IC-7100
    /// override — v1.2.16 pre-release testing surfaced exactly
    /// this bug before shipping.
    var requiresPreTransactionFlush: Bool { get }

    /// Format a mode read command.
    /// - Returns: Command bytes
    func readModeCommand() -> [UInt8]

    /// Parse a mode response from the radio.
    /// - Parameter response: CI-V frame response
    /// - Returns: Mode code (e.g., 0x00 for LSB)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    func parseModeResponse(_ response: CIVFrame) throws -> UInt8

    /// The DATA flag carried in a mode reply, for radios whose mode
    /// codes include DATA variants (IC-F8101: LSB-D1 `0x18`, USB-D1
    /// `0x19`), or `nil` for the usual radios, where DATA travels in
    /// `0x26` or `0x1A 0x06`. When non-`nil`, `getMode` uses it instead
    /// of reading or guessing the flag.
    ///
    /// - Parameter response: The reply to ``readModeCommand()``.
    /// - Returns: Whether the reply reports a DATA mode, or `nil`.
    func parseDataModeFlag(_ response: CIVFrame) -> Bool?

    // MARK: - Power Commands

    /// Format a power set command.
    /// - Parameter value: Power value (percentage or watts depending on powerUnits)
    /// - Returns: Command bytes and data bytes
    func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8])

    /// Format a power read command.
    /// - Returns: Command bytes
    func readPowerCommand() -> [UInt8]

    /// Parse a power response from the radio.
    /// - Parameter response: CI-V frame response
    /// - Returns: Power value (percentage or watts depending on powerUnits)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    func parsePowerResponse(_ response: CIVFrame) throws -> Int

    // MARK: - PTT Commands

    /// Format a PTT (Push-To-Talk) control command.
    /// - Parameter enabled: true to transmit, false to receive
    /// - Returns: Command bytes and data bytes
    func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8])

    /// Format a PTT status read command.
    /// - Returns: Command bytes
    func readPTTCommand() -> [UInt8]

    /// Parse a PTT response from the radio.
    /// - Parameter response: CI-V frame response
    /// - Returns: true if transmitting, false if receiving
    /// - Throws: `RigError.invalidResponse` if response is malformed
    func parsePTTResponse(_ response: CIVFrame) throws -> Bool

    // MARK: - VFO Commands

    /// Format a VFO selection command.
    /// - Parameter vfo: VFO to select (A, B, main, or sub)
    /// - Returns: Command bytes and data bytes, or nil if VFO selection not required
    func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])?

    // MARK: - Frequency Commands

    /// Format a frequency set command.
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Command bytes and data bytes
    func setFrequencyCommand(frequency: UInt64) -> (command: [UInt8], data: [UInt8])

    /// Format a frequency read command.
    /// - Returns: Command bytes
    func readFrequencyCommand() -> [UInt8]

    /// Parse a frequency response from the radio.
    /// - Parameter response: CI-V frame response
    /// - Returns: Frequency in Hz
    /// - Throws: `RigError.invalidResponse` if response is malformed
    func parseFrequencyResponse(_ response: CIVFrame) throws -> UInt64
}

extension CIVCommandSet {
    /// Default: assume the command set carries the data flag in
    /// its own `setDataModeCommand` frame (no follow-up needed).
    /// Real Icom command sets override this — see
    /// ``IcomRadioCommandSet/requiresDataModeSubCommand``.
    public var requiresDataModeSubCommand: Bool { false }

    /// Default: no `0x26`. Real Icom command sets override this — see
    /// ``IcomRadioCommandSet/usesSelectedVFOModeCommand``.
    public var usesSelectedVFOModeCommand: Bool { false }

    /// Default: the mode reply carries no DATA flag.
    public func parseDataModeFlag(_ response: CIVFrame) -> Bool? { nil }

    /// Default: no pre-transaction flush.  Overridden on radios
    /// (currently IC-7100 / IC-705) that share a single USB
    /// endpoint between async transceive notifications and CAT
    /// command replies.  See
    /// ``IcomRadioCommandSet/requiresPreTransactionFlush`` for
    /// the Hamlib citation and full rationale.
    public var requiresPreTransactionFlush: Bool { false }
}
