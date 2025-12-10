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

    /// Format a mode set command.
    /// - Parameter mode: The operating mode code to set (e.g., 0x00 for LSB)
    /// - Returns: Command bytes and data bytes
    func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8])

    /// Format a mode read command.
    /// - Returns: Command bytes
    func readModeCommand() -> [UInt8]

    /// Parse a mode response from the radio.
    /// - Parameter response: CI-V frame response
    /// - Returns: Mode code (e.g., 0x00 for LSB)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    func parseModeResponse(_ response: CIVFrame) throws -> UInt8

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
