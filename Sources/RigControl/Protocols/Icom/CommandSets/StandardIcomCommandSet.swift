import Foundation

/// Standard CI-V command set for most Icom radios.
///
/// This command set implements the "standard" CI-V protocol used by the majority of Icom radios.
/// It uses the `IcomRadioCommandSet` protocol with sensible defaults that work for ~90% of radios.
///
/// ## Standard CI-V Characteristics
/// - **Mode Filter**: REQUIRED - Mode commands include filter byte
/// - **Command Echo**: NO - Most radios don't echo commands
/// - **VFO Model**: Configurable (targetable, currentOnly, or mainSub)
/// - **Power Display**: Percentage (0-100%) for all Icom radios
///
/// ## Radios Using This Command Set
/// This command set is suitable for:
/// - **HF transceivers**: IC-7300, IC-7610, IC-7600, IC-7700, IC-7800, IC-7200, IC-7410
/// - **HF/VHF transceivers**: IC-9100, IC-746PRO, IC-7000
/// - **VHF/UHF mobiles**: ID-5100, ID-4100
/// - **Receivers**: IC-R8600, IC-R75, IC-R9500
///
/// ## Exceptions (Don't Use This)
/// - **IC-7100/IC-705**: Use `IC7100CommandSet` (no filter byte, echoes commands)
/// - **IC-9700**: Use `IC9700CommandSet` (uses Main/Sub VFO model)
///
/// ## Customization
/// You can customize behavior by passing parameters to the initializer:
/// ```swift
/// // IC-7200 (operates on current VFO, requires filter)
/// let ic7200 = StandardIcomCommandSet(
///     civAddress: 0x76,
///     vfoModel: .currentOnly,
///     echoesCommands: false
/// )
///
/// // IC-7610 (can target VFO, dual receiver capable)
/// let ic7610 = StandardIcomCommandSet(
///     civAddress: 0x98,
///     vfoModel: .mainSub,  // Has dual receiver
///     echoesCommands: false
/// )
/// ```
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with all methods inherited from default implementations.
/// Only properties need to be set - zero code duplication!
public struct StandardIcomCommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel
    public let requiresModeFilter: Bool
    public let echoesCommands: Bool
    public let powerUnits: PowerUnits

    /// Initialize a standard Icom command set.
    /// - Parameters:
    ///   - civAddress: Radio's CI-V address
    ///   - vfoModel: VFO operation model (default: .targetable)
    ///   - requiresModeFilter: Whether mode commands need filter byte (default: true)
    ///   - echoesCommands: Whether radio echoes commands (default: false)
    public init(
        civAddress: UInt8,
        vfoModel: VFOOperationModel = .targetable,
        requiresModeFilter: Bool = true,
        echoesCommands: Bool = false
    ) {
        self.civAddress = civAddress
        self.vfoModel = vfoModel
        self.requiresModeFilter = requiresModeFilter
        self.echoesCommands = echoesCommands
        self.powerUnits = .percentage  // All Icom radios use percentage
    }

    // All command methods inherited from IcomRadioCommandSet protocol extension!
    // No need to implement:
    // - selectVFOCommand() - automatic based on vfoModel
    // - setModeCommand() - automatic based on requiresModeFilter
    // - setPowerCommand() - standard percentage format
    // - setPTTCommand() - standard PTT
    // - setFrequencyCommand() - standard BCD encoding
    // - All parse methods - standard CI-V response parsing
}

// MARK: - Convenience Initializers for Specific Radios

extension StandardIcomCommandSet {
    /// IC-7300 HF/50MHz entry-level transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 115200 baud, 100W, requires mode filter
    public static var ic7300: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x94, vfoModel: .targetable)
    }

    /// IC-7610 HF/50MHz SDR transceiver with dual receivers
    /// - VFO Model: Main/Sub (dual receiver architecture)
    /// - 115200 baud, 100W, requires mode filter
    public static var ic7610: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x98, vfoModel: .mainSub)
    }

    /// IC-7600 HF/50MHz high-end transceiver with dual receiver
    /// - VFO Model: Main/Sub (dual receiver, NOT VFO A/B)
    /// - Note: Uses Main/Sub bands, operates on currently selected band
    /// - 19200 baud, 100W, requires mode filter
    public static var ic7600: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7A, vfoModel: .mainSub)
    }

    /// IC-9100 HF/VHF/UHF all-mode transceiver with dual receivers
    /// - VFO Model: Main/Sub (dual receiver architecture)
    /// - 115200 baud, 100W, requires mode filter
    public static var ic9100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7C, vfoModel: .mainSub)
    }

    /// IC-7200 HF/50MHz mid-range transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic7200: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x76, vfoModel: .currentOnly)
    }

    /// IC-7410 HF/50MHz transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic7410: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x80, vfoModel: .currentOnly)
    }

    /// IC-7700 HF/50MHz high-power flagship transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 200W, requires mode filter
    public static var ic7700: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x74, vfoModel: .targetable)
    }

    /// IC-7800 HF/50MHz high-power flagship transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 200W, requires mode filter
    public static var ic7800: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x6A, vfoModel: .targetable)
    }

    /// IC-7000 HF/VHF/UHF mobile transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic7000: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x70, vfoModel: .currentOnly)
    }

    /// IC-756PROIII HF/50MHz transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic756PROIII: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x6E, vfoModel: .targetable)
    }

    /// IC-756PROII HF/50MHz transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic756PROII: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x64, vfoModel: .targetable)
    }

    /// IC-756PRO HF/50MHz transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic756PRO: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x5C, vfoModel: .targetable)
    }

    /// IC-746PRO HF/VHF transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic746PRO: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x66, vfoModel: .targetable)
    }

    /// ID-5100 VHF/UHF mobile transceiver with D-STAR
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 50W, requires mode filter
    public static var id5100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x86, vfoModel: .targetable)
    }

    /// ID-4100 VHF/UHF mobile transceiver with D-STAR
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 65W, requires mode filter
    public static var id4100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x76, vfoModel: .targetable)
    }

    /// IC-R8600 wideband communications receiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 115200 baud, receiver only (no PTT/power control)
    public static var icR8600: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x96, vfoModel: .targetable)
    }

    /// IC-R75 HF communications receiver
    /// - VFO Model: None (single VFO receiver)
    /// - 19200 baud, receiver only (no PTT/power control)
    public static var icR75: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x5A, vfoModel: .none)
    }

    /// IC-R9500 professional communications receiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, receiver only (no PTT/power control)
    public static var icR9500: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7A, vfoModel: .targetable)
    }
}
