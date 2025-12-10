import Foundation

/// CI-V command set for Icom IC-9700.
///
/// The IC-9700 is a VHF/VHF/UHF/1.2GHz all-mode transceiver with the following CI-V characteristics:
/// - **CI-V Address**: 0xA2
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: NO - Radio does not echo commands
/// - **Mode Filter**: REQUIRED - Mode commands must include filter byte
/// - **VFO Selection**: REQUIRED - Commands need explicit VFO selection
///
/// ## Key Differences from IC-7100
/// 1. Requires filter byte in mode commands: `[mode, filter]`
/// 2. Does not echo commands (unlike IC-7100)
/// 3. Requires explicit VFO selection for frequency/mode changes
/// 4. Supports dual receivers (main/sub)
///
/// ## Power Display
/// Like all Icom radios, the IC-9700 displays power as percentage (0-100%),
/// independent of the actual max power output (100W for IC-9700).
/// Source: Hamlib GitHub issue #533, confirmed across all Icom radios.
public struct IC9700CommandSet: CIVCommandSet {
    public let civAddress: UInt8 = 0xA2
    public let powerUnits: PowerUnits = .percentage
    public let echoesCommands: Bool = false
    public let requiresVFOSelection: Bool = true

    public init() {}

    // MARK: - Mode Commands

    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // IC-9700 requires filter byte (0x00 = default filter)
        return ([0x06], [mode, 0x00])
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
        // IC-9700 uses percentage (0-100%)
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
        // IC-9700 requires VFO selection
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
