import Foundation

/// Enhanced protocol for Icom radio command sets with smart default implementations.
///
/// This protocol extends `CIVCommandSet` to provide intelligent default implementations
/// based on radio behavioral characteristics. Instead of using ambiguous boolean flags,
/// it uses explicit enums and types to describe radio behavior.
///
/// ## Design Philosophy
/// - **Explicit over implicit**: Use `VFOOperationModel` instead of `requiresVFOSelection`
/// - **Behavior-based**: Group radios by how they behave, not by model number
/// - **Minimal override**: Radios only override what's different from standard
/// - **Type-safe**: Compiler enforces correct VFO codes and command formats
///
/// ## Adding a New Radio
/// ```swift
/// struct IC7700CommandSet: IcomRadioCommandSet {
///     let civAddress: UInt8 = 0x74
///     let vfoModel: VFOOperationModel = .targetable
///     let requiresModeFilter = true
///     let echoesCommands = false
///     let powerUnits: PowerUnits = .percentage
///     // All command methods inherited from protocol extension!
/// }
/// ```
///
/// ## VFO Operation Models
/// - **targetable**: Can target VFO A/B directly (IC-7300, IC-7610, IC-7700, IC-7800)
/// - **currentOnly**: Operates on current VFO (IC-7100, IC-705, IC-7200, IC-7410)
/// - **mainSub**: Uses Main/Sub receivers (IC-7600, IC-9700, IC-9100 dual RX)
/// - **none**: No VFO support (receivers)
public protocol IcomRadioCommandSet: CIVCommandSet {
    /// VFO operation model for this radio
    var vfoModel: VFOOperationModel { get }

    /// Whether mode commands require filter byte (0x00 = default filter)
    ///
    /// - **true**: Modern radios with DSP filters (IC-7300, IC-7610, IC-9700, IC-9100, IC-7600, IC-7200, IC-7410)
    /// - **false**: IC-7100 family (IC-7100, IC-705) - these radios NAK if filter byte is sent
    var requiresModeFilter: Bool { get }
}

// MARK: - Default Implementations

extension IcomRadioCommandSet {
    /// Default VFO selection implementation based on VFO operation model.
    ///
    /// Automatically handles the three different VFO architectures:
    /// - **Targetable/CurrentOnly**: Uses standard VFO A/B codes (0x00/0x01)
    /// - **MainSub**: Uses Main/Sub codes (0xD0/0xD1), returns nil for VFO A/B
    /// - **None**: Returns nil (VFO selection not supported)
    public func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])? {
        switch vfoModel {
        case .targetable, .currentOnly:
            // Standard VFO A/B selection
            let vfoCode = VFOCodeHelper.standardCode(for: vfo)
            return ([CIVFrame.Command.selectVFO], [vfoCode])

        case .mainSub:
            // Main/Sub receiver architecture
            // Returns nil if user tries to use VFO A/B on a Main/Sub radio
            guard let vfoCode = VFOCodeHelper.mainSubCode(for: vfo) else {
                return nil
            }
            return ([CIVFrame.Command.selectVFO], [vfoCode])

        case .none:
            // No VFO support
            return nil
        }
    }

    /// Whether this radio requires VFO selection before frequency/mode commands.
    ///
    /// This is computed from the VFO model:
    /// - **targetable**: true (must select target VFO)
    /// - **currentOnly**: true (must switch to desired VFO)
    /// - **mainSub**: true (must select Main/Sub)
    /// - **none**: false (no VFO operations)
    public var requiresVFOSelection: Bool {
        switch vfoModel {
        case .targetable, .currentOnly, .mainSub:
            return true
        case .none:
            return false
        }
    }

    // MARK: - Mode Commands

    /// Default mode set command implementation.
    ///
    /// Handles filter byte based on `requiresModeFilter`:
    /// - If true: Sends mode + filter byte (0x01 = FIL1, default filter per IC-7600 manual)
    /// - If false: Sends mode only (IC-7100 family)
    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        if requiresModeFilter {
            // Standard: mode + filter byte
            // Per IC-7600 CI-V manual: Valid filter codes are 01=FIL1, 02=FIL2, 03=FIL3
            // Using 0x01 (FIL1) as default - 0x00 is NOT valid and causes NAK response
            return ([CIVFrame.Command.setMode], [mode, 0x01])
        } else {
            // IC-7100 family: mode only (NAKs if filter byte sent)
            return ([CIVFrame.Command.setMode], [mode])
        }
    }

    public func readModeCommand() -> [UInt8] {
        return [CIVFrame.Command.readMode]
    }

    public func parseModeResponse(_ response: CIVFrame) throws -> UInt8 {
        guard response.command.count == 1,
              response.command[0] == CIVFrame.Command.readMode,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    // MARK: - Frequency Commands

    public func setFrequencyCommand(frequency: UInt64) -> (command: [UInt8], data: [UInt8]) {
        let bcd = BCDEncoding.encodeFrequency(frequency)
        return ([CIVFrame.Command.setFrequency], bcd)
    }

    public func readFrequencyCommand() -> [UInt8] {
        return [CIVFrame.Command.readFrequency]
    }

    public func parseFrequencyResponse(_ response: CIVFrame) throws -> UInt64 {
        guard response.command.count == 1,
              response.command[0] == CIVFrame.Command.readFrequency,
              response.data.count == 5 else {
            throw RigError.invalidResponse
        }
        return try BCDEncoding.decodeFrequency(response.data)
    }

    // MARK: - Power Commands

    /// Default power set command implementation.
    ///
    /// All Icom radios use percentage (0-100%) for power display.
    /// Command: 0x14 0x0A (Set RF Power Level)
    public func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        // Clamp to 0-100%
        let percentage = min(max(value, 0), 100)
        // Scale to 0-255 for BCD encoding
        let scale = (percentage * 255) / 100
        let bcd = BCDEncoding.encodePower(scale)
        return ([CIVFrame.Command.settings, CIVFrame.SettingsCode.rfPower], bcd)
    }

    public func readPowerCommand() -> [UInt8] {
        return [CIVFrame.Command.settings, CIVFrame.SettingsCode.rfPower]
    }

    public func parsePowerResponse(_ response: CIVFrame) throws -> Int {
        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.settings,
              response.command[1] == CIVFrame.SettingsCode.rfPower,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }
        let scale = BCDEncoding.decodePower(response.data)
        // Convert back to percentage
        return (scale * 100) / 255
    }

    // MARK: - PTT Commands

    /// Default PTT command implementation.
    ///
    /// Command: 0x1C 0x00 (PTT control)
    /// Data: 0x01 = transmit, 0x00 = receive
    public func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([CIVFrame.Command.ptt, 0x00], [enabled ? 0x01 : 0x00])
    }

    public func readPTTCommand() -> [UInt8] {
        return [CIVFrame.Command.ptt, 0x00]
    }

    public func parsePTTResponse(_ response: CIVFrame) throws -> Bool {
        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.ptt,
              response.command[1] == 0x00,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }
}

// MARK: - Convenience Protocol for Standard Radios

/// Protocol for "standard" Icom radios that follow modern CI-V conventions.
///
/// Use this for most radios manufactured after 2010 that:
/// - Require mode filter byte
/// - Don't echo commands
/// - Use targetable VFO model
/// - Display power as percentage
///
/// Examples: IC-7300, IC-7610, IC-7700, IC-7800, IC-9100, IC-7200, IC-7410
public protocol StandardIcomRadio: IcomRadioCommandSet {}

extension StandardIcomRadio {
    // Standard defaults for modern radios
    public var vfoModel: VFOOperationModel { .targetable }
    public var requiresModeFilter: Bool { true }
    public var echoesCommands: Bool { false }
    public var powerUnits: PowerUnits { .percentage }
}
