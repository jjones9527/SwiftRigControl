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
    /// Automatically handles the different VFO architectures:
    /// - **Targetable/CurrentOnly**: Uses standard VFO A/B codes (0x00/0x01)
    /// - **MainSub**: Uses Main/Sub codes (0xD0/0xD1), returns nil for VFO A/B
    /// - **MainSubDualVFO**: Accepts BOTH Main/Sub (0xD0/0xD1) AND VFO A/B (0x00/0x01)
    /// - **None**: Returns nil (VFO selection not supported)
    public func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])? {
        switch vfoModel {
        case .targetable, .currentOnly:
            // Standard VFO A/B selection
            let vfoCode = VFOCodeHelper.standardCode(for: vfo)
            return ([CIVFrame.Command.selectVFO], [vfoCode])

        case .mainSub:
            // Main/Sub receiver architecture (2-state: Main or Sub only)
            // .main/.sub map directly; .a/.b fall back to Main/Sub (A=Main, B=Sub)
            // so that callers using the conventional VFO A/B API still get a valid selection.
            let vfoCode: UInt8
            switch vfo {
            case .main, .a: vfoCode = CIVFrame.VFOSelect.main  // 0xD0
            case .sub, .b:  vfoCode = CIVFrame.VFOSelect.sub   // 0xD1
            }
            return ([CIVFrame.Command.selectVFO], [vfoCode])

        case .mainSubDualVFO:
            // Main/Sub receiver with VFO A/B per receiver (4-state)
            // Supports BOTH band selection (.main/.sub) AND VFO selection (.a/.b)
            if let bandCode = VFOCodeHelper.mainSubCode(for: vfo) {
                // Band selection (Main=0xD0, Sub=0xD1)
                return ([CIVFrame.Command.selectVFO], [bandCode])
            } else if let vfoCode = VFOCodeHelper.dualVFOCode(for: vfo) {
                // VFO selection (A=0x00, B=0x01) on current receiver
                return ([CIVFrame.Command.selectVFO], [vfoCode])
            } else {
                return nil
            }

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
    /// - **mainSubDualVFO**: true (must select band and/or VFO)
    /// - **none**: false (no VFO operations)
    public var requiresVFOSelection: Bool {
        switch vfoModel {
        case .targetable, .currentOnly, .mainSub, .mainSubDualVFO:
            return true
        case .none:
            return false
        }
    }

    // MARK: - Mode Commands

    /// Whether this radio supports VFO-targeted mode commands via 0x26.
    ///
    /// Targetable radios (IC-7300, IC-7610, IC-7700, IC-7800, IC-7851) use
    /// `C_SEND_SEL_MODE (0x26)` which carries a 3-byte payload:
    /// `[mode_byte, data_flag (0x01=DATA / 0x00=normal), filter_byte]`.
    /// This is the Hamlib-preferred path for DATA mode on modern radios.
    public var supportsTargetableMode: Bool {
        vfoModel == .targetable
    }

    /// Default mode set command for normal (non-data) modes.
    ///
    /// Handles filter byte based on `requiresModeFilter`:
    /// - If true: Sends mode + filter byte (0x01 = FIL1, default filter)
    /// - If false: Sends mode only (IC-7100 family — NAKs if filter byte sent)
    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        if requiresModeFilter {
            return ([CIVFrame.Command.setMode], [mode, CIVFrame.FilterCode.fil1])
        } else {
            return ([CIVFrame.Command.setMode], [mode])
        }
    }

    /// Mode set command for DATA modes.
    ///
    /// Three different wire shapes depending on the radio:
    ///
    /// - **Targetable** (IC-7300, IC-7610, IC-7700, IC-7800,
    ///   IC-7851): single frame `0x26 [mode, data_flag=0x01,
    ///   filter=FIL1]` that carries the DATA flag in the same
    ///   command. No follow-up needed.
    /// - **`requiresDataModeSubCommand` radios** (IC-7600,
    ///   IC-9100, IC-9700, IC-7100, IC-705, …): send the base
    ///   mode first via the normal `setModeCommand` path, then
    ///   `IcomCIVProtocol.setMode` follows up with `0x1A 0x06
    ///   [0x01, filter]` to flip the DATA sub-mode bit. The
    ///   value returned here is the base-mode frame; the
    ///   protocol takes care of the second frame.
    /// - **Legacy** radios without `data_mode_supported` (older
    ///   IC-7200 etc.): fall back to the original `0x06 [mode,
    ///   filter=0x00]` shorthand, kept for compatibility.
    ///
    /// Matches Hamlib `icom_set_mode` for each family
    /// (rigs/icom/icom.c:2494). Cross-checked against
    /// `icom_set_mode_x26`, `S_MEM_DATA_MODE`, and
    /// `data_mode_supported` per-radio.
    public func setDataModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        if supportsTargetableMode {
            // Targetable: 0x26 [mode, data_flag=0x01, filter=FIL1]
            return ([CIVFrame.Command.targetableMode], [mode, 0x01, CIVFrame.FilterCode.fil1])
        } else if requiresDataModeSubCommand {
            // Non-targetable with explicit 0x1A 0x06 follow-up:
            // send the normal base-mode frame here; the protocol
            // sends 0x1A 0x06 separately to flip the data bit.
            return setModeCommand(mode: mode)
        } else if requiresModeFilter {
            // Legacy radios without data_mode_supported: the old
            // 0x06 [mode, filter=0x00] shorthand. Kept for
            // backward compatibility with any radio whose driver
            // historically relied on this.
            return ([CIVFrame.Command.setMode], [mode, CIVFrame.FilterCode.data])
        } else {
            // No filter byte, no follow-up. (No shipping radio
            // in our catalog hits this branch; reserved for a
            // future minimal-CAT radio.)
            return ([CIVFrame.Command.setMode], [mode])
        }
    }

    /// Whether this radio needs the separate `0x1A 0x06
    /// [data_flag, filter]` follow-up to enter/exit a DATA
    /// sub-mode after the base mode has been set.
    ///
    /// Defaults to `true` for non-targetable radios — that's the
    /// path Hamlib's `icom_set_mode` takes for every radio with
    /// `data_mode_supported = 1` that doesn't claim the
    /// targetable-mode capability bit. Targetable radios return
    /// `false` because the `0x26` command already carries the
    /// data flag in its payload.
    ///
    /// Override on a per-radio command set if a specific model
    /// genuinely doesn't accept the follow-up (none in our
    /// current catalog do).
    public var requiresDataModeSubCommand: Bool {
        !supportsTargetableMode
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
