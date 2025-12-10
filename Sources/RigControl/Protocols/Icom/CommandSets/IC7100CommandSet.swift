import Foundation

/// CI-V command set for Icom IC-7100.
///
/// The IC-7100 is an HF/VHF/UHF all-mode transceiver with the following CI-V characteristics:
/// - **CI-V Address**: 0x88
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: YES - Radio echoes commands before sending response
/// - **Mode Filter**: NOT required - Rejects filter byte in mode commands
/// - **VFO Operation**: Operates on "current" VFO - must switch VFO before operations
///
/// ## Key Quirks
/// 1. Power is displayed as percentage, independent of band
/// 2. Echoes all commands back before sending actual response
/// 3. Mode commands must NOT include filter byte (use 0x06 with mode only)
/// 4. PTT uses sub-command format: 0x1C 0x00
/// 5. VFO must be explicitly switched (0x07) before frequency/mode operations
///    - Unlike IC-7300/IC-9700, frequency/mode commands operate on "current" VFO
///    - To change VFO B frequency, first select VFO B (0x07 0x01), then set frequency
///
/// ## Hardware Verification
/// All commands hardware-verified on IC-7100 (December 2025)
public struct IC7100CommandSet: CIVCommandSet {
    public let civAddress: UInt8 = 0x88
    public let powerUnits: PowerUnits = .percentage
    public let echoesCommands: Bool = true
    public let requiresVFOSelection: Bool = false

    public init() {}

    // MARK: - Mode Commands

    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // IC-7100 rejects filter byte - mode data only
        return ([0x06], [mode])
    }

    public func readModeCommand() -> [UInt8] {
        return [0x04]
    }

    public func parseModeResponse(_ response: CIVFrame) throws -> UInt8 {
        guard response.command.count == 1,
              response.command[0] == 0x04,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    // MARK: - Power Commands

    public func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        // IC-7100 uses percentage (0-100%)
        let percentage = min(max(value, 0), 100)
        let scale = (percentage * 255) / 100
        let bcd = BCDEncoding.encodePower(scale)
        return ([0x14, 0x0A], bcd)
    }

    public func readPowerCommand() -> [UInt8] {
        return [0x14, 0x0A]
    }

    public func parsePowerResponse(_ response: CIVFrame) throws -> Int {
        guard response.command.count >= 2,
              response.command[0] == 0x14,
              response.command[1] == 0x0A,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }
        let scale = BCDEncoding.decodePower(response.data)
        return (scale * 100) / 255  // Return percentage
    }

    // MARK: - PTT Commands

    public func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([0x1C, 0x00], [enabled ? 0x01 : 0x00])
    }

    public func readPTTCommand() -> [UInt8] {
        return [0x1C, 0x00]
    }

    public func parsePTTResponse(_ response: CIVFrame) throws -> Bool {
        guard response.command.count >= 2,
              response.command[0] == 0x1C,
              response.command[1] == 0x00,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    // MARK: - VFO Commands

    public func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])? {
        // IC-7100 supports VFO selection to switch the active VFO
        // It operates on the "current" VFO, so we need to switch it when requested
        let vfoCode: UInt8
        switch vfo {
        case .a:
            vfoCode = CIVFrame.VFOSelect.vfoA
        case .b:
            vfoCode = CIVFrame.VFOSelect.vfoB
        case .main:
            vfoCode = CIVFrame.VFOSelect.main
        case .sub:
            vfoCode = CIVFrame.VFOSelect.sub
        }
        return ([0x07], [vfoCode])
    }

    // MARK: - Frequency Commands

    public func setFrequencyCommand(frequency: UInt64) -> (command: [UInt8], data: [UInt8]) {
        let bcd = BCDEncoding.encodeFrequency(frequency)
        return ([0x05], bcd)
    }

    public func readFrequencyCommand() -> [UInt8] {
        return [0x03]
    }

    public func parseFrequencyResponse(_ response: CIVFrame) throws -> UInt64 {
        guard response.command.count == 1,
              response.command[0] == 0x03,
              response.data.count == 5 else {
            throw RigError.invalidResponse
        }
        return try BCDEncoding.decodeFrequency(response.data)
    }
}
