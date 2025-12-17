import Foundation

/// CI-V command set for Icom IC-756 series radios.
///
/// The IC-756 series are HF/6m base station transceivers with Main/Sub receiver architecture.
/// - **CI-V Address**: 0x50 (IC-756), 0x5C (IC-756PRO), 0x64 (IC-756PROII), 0x6E (IC-756PROIII)
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: NO - Does not echo commands
/// - **Mode Filter**: REQUIRED - Standard filter byte support (PRO models), custom for IC-756
/// - **VFO Operation**: Main/Sub receiver architecture
///
/// ## Key Characteristics
/// 1. **Dual receiver**: Main/Sub architecture instead of VFO A/B
/// 2. **Filter evolution**: IC-756 uses simplified normal/narrow, PRO models use standard filter
/// 3. **Band stacking**: 3 registers per ham band, rotates on band change
/// 4. **IC-756PRO known issue**: VOX/Anti-VOX levels incorrectly handled (per Hamlib)
///
/// ## Radios Using This Command Set
/// - **IC-756** (0x50) - Original model with custom filter handling
/// - **IC-756PRO** (0x5C) - Enhanced with standard filter support
/// - **IC-756PROII** (0x64) - Adds custom SSB bass tone, memory names
/// - **IC-756PROIII** (0x6E) - Enhanced DSP features
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with:
/// - `vfoModel = .mainSub` (dual receiver Main/Sub)
/// - `requiresModeFilter = true` (requires filter byte)
/// - `echoesCommands = false` (no command echo)
/// - All methods inherited from protocol default implementations
public struct IC756CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel = .mainSub
    public let requiresModeFilter = true
    public let echoesCommands = false
    public let powerUnits: PowerUnits = .percentage

    /// Initialize IC-756 command set
    /// - Parameter civAddress: CI-V address (0x50/0x5C/0x64/0x6E)
    public init(civAddress: UInt8 = 0x50) {
        self.civAddress = civAddress
    }

    // All command methods inherited from IcomRadioCommandSet protocol extension!
    // No need to reimplement:
    // - selectVFOCommand() - uses .mainSub model
    // - setModeCommand() - includes filter byte
    // - setPowerCommand() - percentage format
    // - setPTTCommand() - standard PTT
    // - setFrequencyCommand() - standard BCD encoding
    // - All parse methods - standard CI-V response parsing
}

// MARK: - Convenience Initializers

extension IC756CommandSet {
    /// IC-756 HF/6m base station transceiver with dual receiver
    public static var ic756: IC756CommandSet {
        IC756CommandSet(civAddress: 0x50)
    }

    /// IC-756PRO HF/6m base station transceiver with enhanced features
    public static var ic756PRO: IC756CommandSet {
        IC756CommandSet(civAddress: 0x5C)
    }

    /// IC-756PROII HF/6m base station transceiver with advanced DSP
    public static var ic756PROII: IC756CommandSet {
        IC756CommandSet(civAddress: 0x64)
    }

    /// IC-756PROIII HF/6m base station transceiver, top of line
    public static var ic756PROIII: IC756CommandSet {
        IC756CommandSet(civAddress: 0x6E)
    }
}
