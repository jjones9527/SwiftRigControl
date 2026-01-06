import Foundation

/// CI-V command set for Icom IC-9700.
///
/// The IC-9700 is a VHF/UHF/1.2GHz all-mode transceiver with dual receiver capability.
/// - **CI-V Address**: 0xA2
/// - **Power Display**: Percentage (0-100%), NOT watts
/// - **Command Echo**: YES - Radio echoes commands before responses (over USB)
/// - **Mode Filter**: NO - Mode commands do NOT include filter byte
/// - **VFO Model**: Main/Sub (dual receiver architecture, NOT VFO A/B)
///
/// ## Key Characteristics
/// 1. **Dual Receiver**: Uses Main (0xD0) and Sub (0xD1) instead of VFO A/B
/// 2. **Mode filter NOT required**: Mode commands use `[mode]` format (no filter byte)
/// 3. **Command echo**: Like IC-7100/IC-705, echoes commands over USB
/// 4. **VHF/UHF/1.2GHz**: 144-148 MHz (2m), 430-450 MHz (70cm), 1240-1300 MHz (23cm)
///
/// ## Power Display
/// Like all Icom radios, the IC-9700 displays power as percentage (0-100%),
/// independent of the actual max power output (100W for IC-9700).
/// Source: Hamlib GitHub issue #533, confirmed across all Icom radios.
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with:
/// - `vfoModel = .mainSubDualVFO` (4-state: Main/Sub receivers, EACH with VFO A/B)
/// - `requiresModeFilter = false` (NO filter byte)
/// - `echoesCommands = true` (echoes commands over USB)
/// - All methods inherited from protocol default implementations
public struct IC9700CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8 = 0xA2
    public let vfoModel: VFOOperationModel = .mainSubDualVFO  // IC-9700 uses 4-state VFO model
    public let requiresModeFilter = false  // IC-9700 does NOT accept filter byte
    public let echoesCommands = true  // IC-9700 echoes commands over USB
    public let powerUnits: PowerUnits = .percentage

    public init() {}

    // All command methods inherited from IcomRadioCommandSet protocol extension!
    // No need to reimplement:
    // - selectVFOCommand() - uses .mainSubDualVFO model (Band: Main=0xD0, Sub=0xD1; VFO: A=0x00, B=0x01)
    // - setModeCommand() - NO filter byte for IC-9700
    // - setPowerCommand() - percentage format
    // - setPTTCommand() - standard PTT
    // - setFrequencyCommand() - standard BCD encoding
    // - All parse methods - standard CI-V response parsing
}
