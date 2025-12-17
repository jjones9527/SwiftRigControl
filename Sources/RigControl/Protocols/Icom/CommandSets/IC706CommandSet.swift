import Foundation

/// CI-V command set for Icom IC-706 series radios.
///
/// The IC-706 series are HF/VHF mobile transceivers with legacy CI-V protocol.
/// - **CI-V Address**: 0x48 (IC-706), 0x4E (IC-706MKII), 0x58 (IC-706MKIIG)
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: NO - Does not echo commands
/// - **Mode Filter**: NOT required - Uses legacy mode commands without filter byte
/// - **VFO Operation**: Targetable VFO A/B architecture
///
/// ## Key Characteristics
/// 1. **Legacy mode commands**: Command 0x04 without filter byte
/// 2. **No echo**: Does not echo commands over USB
/// 3. **Basic CI-V**: Original CI-V protocol from 1990s era
/// 4. **Wide FM**: Receive only, no WFM transmit
///
/// ## Radios Using This Command Set
/// - **IC-706** (0x48) - HF/6m/2m, 100W HF
/// - **IC-706MKII** (0x4E) - Enhanced IC-706
/// - **IC-706MKIIG** (0x58) - Adds 70cm, 100W HF/50W VHF/20W UHF
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with:
/// - `vfoModel = .targetable` (can target VFO A/B directly)
/// - `requiresModeFilter = false` (legacy mode without filter)
/// - `echoesCommands = false` (no command echo)
/// - All methods inherited from protocol default implementations
public struct IC706CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel = .targetable
    public let requiresModeFilter = false
    public let echoesCommands = false
    public let powerUnits: PowerUnits = .percentage

    /// Initialize IC-706 command set
    /// - Parameter civAddress: CI-V address (0x48 for IC-706, 0x4E for MKII, 0x58 for MKIIG)
    public init(civAddress: UInt8 = 0x48) {
        self.civAddress = civAddress
    }

    // All command methods inherited from IcomRadioCommandSet protocol extension!
    // No need to reimplement:
    // - selectVFOCommand() - uses .targetable model
    // - setModeCommand() - no filter byte
    // - setPowerCommand() - percentage format
    // - setPTTCommand() - standard PTT
    // - setFrequencyCommand() - standard BCD encoding
    // - All parse methods - standard CI-V response parsing
}

// MARK: - Convenience Initializers

extension IC706CommandSet {
    /// IC-706 HF/6m/2m mobile transceiver
    public static var ic706: IC706CommandSet {
        IC706CommandSet(civAddress: 0x48)
    }

    /// IC-706MKII HF/6m/2m mobile transceiver
    public static var ic706MKII: IC706CommandSet {
        IC706CommandSet(civAddress: 0x4E)
    }

    /// IC-706MKIIG HF/VHF/UHF mobile transceiver
    public static var ic706MKIIG: IC706CommandSet {
        IC706CommandSet(civAddress: 0x58)
    }
}
