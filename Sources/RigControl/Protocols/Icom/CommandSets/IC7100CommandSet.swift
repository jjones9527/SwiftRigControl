import Foundation

/// CI-V command set for Icom IC-7100 and IC-705.
///
/// The IC-7100 family has unique CI-V characteristics that differ from standard Icom radios:
/// - **CI-V Address**: 0x88 (IC-7100), 0xA4 (IC-705)
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: YES - Radio echoes commands before sending response
/// - **Mode Filter**: NOT required - Rejects filter byte in mode commands (NAKs if sent)
/// - **VFO Operation**: Operates on "current" VFO - must switch VFO before operations
///
/// ## Key Quirks
/// 1. **No filter byte**: Mode command 0x06 must send mode only (not mode+filter)
/// 2. **Command echo**: All commands are echoed back before actual response
/// 3. **Current VFO only**: Unlike IC-7300/IC-7610 which can target VFO directly,
///    IC-7100/IC-705 operate only on the "current" VFO
/// 4. **VFO switching required**: To change VFO B, must first switch to VFO B (0x07 0x01)
///
/// ## Radios Using This Command Set
/// - **IC-7100** (0x88) - HF/VHF/UHF mobile transceiver, 100W
/// - **IC-705** (0xA4) - HF/VHF/UHF portable transceiver, 10W
///
/// ## Hardware Verification
/// All commands hardware-verified on IC-7100 (December 2025)
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with:
/// - `vfoModel = .currentOnly` (operates on current VFO)
/// - `requiresModeFilter = false` (rejects filter byte)
/// - `echoesCommands = true` (echoes all commands)
/// - All other methods inherited from protocol default implementations
public struct IC7100CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel = .currentOnly
    public let requiresModeFilter = false
    public let echoesCommands = true
    public let powerUnits: PowerUnits = .percentage

    /// Initialize IC-7100 command set
    /// - Parameter civAddress: CI-V address (0x88 for IC-7100, 0xA4 for IC-705)
    public init(civAddress: UInt8 = 0x88) {
        self.civAddress = civAddress
    }

    // All command methods inherited from IcomRadioCommandSet protocol extension!
    // No need to reimplement:
    // - selectVFOCommand() - uses .currentOnly model
    // - setModeCommand() - no filter byte
    // - setPowerCommand() - percentage format
    // - setPTTCommand() - standard PTT
    // - setFrequencyCommand() - standard BCD encoding
    // - All parse methods - standard CI-V response parsing
}

// MARK: - Convenience Initializers

extension IC7100CommandSet {
    /// IC-7100 HF/VHF/UHF mobile transceiver
    public static var ic7100: IC7100CommandSet {
        IC7100CommandSet(civAddress: 0x88)
    }

    /// IC-705 portable HF/VHF/UHF transceiver
    public static var ic705: IC7100CommandSet {
        IC7100CommandSet(civAddress: 0xA4)
    }
}
