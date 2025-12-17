import Foundation

/// CI-V command set for Icom IC-746 series radios.
///
/// The IC-746 series are HF/6m base station transceivers with legacy CI-V protocol.
/// - **CI-V Address**: 0x56 (IC-746), 0x66 (IC-746PRO)
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: NO - Does not echo commands
/// - **Mode Filter**: NOT required - Uses legacy mode commands without filter byte
/// - **VFO Operation**: Targetable VFO A/B architecture
///
/// ## Key Characteristics
/// 1. **Legacy mode commands**: Command 0x04 without filter byte
/// 2. **No echo**: Standard serial behavior
/// 3. **VHF receive**: Includes 2m receive capability (108-174MHz)
/// 4. **IC-746PRO enhancements**: Extended parameters, DCD support, band stacking
///
/// ## Radios Using This Command Set
/// - **IC-746** (0x56) - Basic model, limited parameters
/// - **IC-746PRO** (0x66) - Enhanced with DCD, extended control, 9-char channel descriptions
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with:
/// - `vfoModel = .targetable` (can target VFO A/B directly)
/// - `requiresModeFilter = false` (legacy mode without filter)
/// - `echoesCommands = false` (no command echo)
/// - All methods inherited from protocol default implementations
public struct IC746CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel = .targetable
    public let requiresModeFilter = false
    public let echoesCommands = false
    public let powerUnits: PowerUnits = .percentage

    /// Initialize IC-746 command set
    /// - Parameter civAddress: CI-V address (0x56 for IC-746, 0x66 for IC-746PRO)
    public init(civAddress: UInt8 = 0x56) {
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

extension IC746CommandSet {
    /// IC-746 HF/6m base station transceiver with 2m receive
    public static var ic746: IC746CommandSet {
        IC746CommandSet(civAddress: 0x56)
    }

    /// IC-746PRO HF/6m base station transceiver with enhanced features
    public static var ic746PRO: IC746CommandSet {
        IC746CommandSet(civAddress: 0x66)
    }
}
