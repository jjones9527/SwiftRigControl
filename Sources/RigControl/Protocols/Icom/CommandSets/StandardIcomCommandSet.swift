import Foundation

/// Standard CI-V command set for most Icom radios.
///
/// This command set implements the "standard" CI-V protocol used by most Icom HF and VHF/UHF radios.
/// It's suitable for radios like:
/// - IC-7300, IC-7610, IC-7600 (HF transceivers)
/// - IC-705 (portable HF/VHF/UHF)
/// - IC-9100 (HF/VHF/UHF base station)
///
/// ## Standard CI-V Characteristics
/// - **Mode Filter**: REQUIRED - Mode commands include filter byte
/// - **Command Echo**: NO - Most radios don't echo commands
/// - **VFO Selection**: REQUIRED - Explicit VFO selection needed
/// - **Power Display**: Percentage (0-100%) for all Icom radios
///
/// ## Customization
/// You can customize behavior by passing parameters to the initializer:
/// ```swift
/// // IC-705 (similar to IC-7100, but different address)
/// let ic705 = StandardIcomCommandSet(
///     civAddress: 0xA4,
///     echoesCommands: true,
///     requiresVFOSelection: false
/// )
/// ```
public struct StandardIcomCommandSet: CIVCommandSet {
    public let civAddress: UInt8
    public let powerUnits: PowerUnits = .percentage
    public let echoesCommands: Bool
    public let requiresVFOSelection: Bool

    /// Initialize a standard Icom command set.
    /// - Parameters:
    ///   - civAddress: Radio's CI-V address
    ///   - echoesCommands: Whether radio echoes commands (default: false)
    ///   - requiresVFOSelection: Whether radio requires VFO selection (default: true)
    public init(civAddress: UInt8, echoesCommands: Bool = false, requiresVFOSelection: Bool = true) {
        self.civAddress = civAddress
        self.echoesCommands = echoesCommands
        self.requiresVFOSelection = requiresVFOSelection
    }

    // MARK: - Mode Commands

    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // Standard Icom radios require filter byte (0x00 = default filter)
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
        // All Icom radios use percentage (0-100%)
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
        guard requiresVFOSelection else { return nil }

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

// MARK: - Convenience Initializers for Specific Radios

extension StandardIcomCommandSet {
    /// IC-705 portable HF/VHF/UHF transceiver
    /// Similar to IC-7100: echoes commands, doesn't require VFO selection
    public static var ic705: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0xA4, echoesCommands: true, requiresVFOSelection: false)
    }

    /// IC-7300 HF/50MHz entry-level transceiver
    public static var ic7300: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x94)
    }

    /// IC-7610 HF/50MHz SDR transceiver with dual receivers
    public static var ic7610: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x98)
    }

    /// IC-7600 HF/50MHz high-end transceiver with dual receiver
    /// Note: Uses Main/Sub bands (not VFO A/B), operates on currently selected band
    public static var ic7600: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7A, echoesCommands: false, requiresVFOSelection: false)
    }

    /// IC-9100 HF/VHF/UHF all-mode transceiver with dual receivers
    public static var ic9100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7C)
    }

    /// IC-7200 HF/50MHz mid-range transceiver
    public static var ic7200: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x76, echoesCommands: false, requiresVFOSelection: false)
    }

    /// IC-7410 HF/50MHz transceiver
    public static var ic7410: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x80, echoesCommands: false, requiresVFOSelection: false)
    }
}
