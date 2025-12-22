import Foundation

/// Enumeration of all supported Icom radio models.
///
/// This enum is used to identify the specific radio model for command selection,
/// independent of the CI-V bus address (which users can configure).
///
/// ## Design Philosophy
/// Radio models determine which commands are available and how they're formatted.
/// CI-V addresses are user-configurable and only used for bus routing.
///
/// ## Usage
/// ```swift
/// let protocol = IcomCIVProtocol(
///     transport: transport,
///     civAddress: 0x7B,  // Custom address (user changed from default 0x7A)
///     radioModel: .ic7600, // Model determines command set
///     commandSet: commandSet,
///     capabilities: capabilities
/// )
/// ```
public enum IcomRadioModel: String, Sendable, CaseIterable {
    // MARK: - HF Transceivers

    /// IC-7600 HF/6m 100W transceiver with dual receiver
    case ic7600 = "IC-7600"

    /// IC-7610 HF/6m 100W SDR transceiver with dual receiver and spectrum scope
    case ic7610 = "IC-7610"

    /// IC-7300 HF/6m 100W SDR transceiver with spectrum scope
    case ic7300 = "IC-7300"

    /// IC-7851 HF/6m 200W flagship transceiver
    case ic7851 = "IC-7851"

    /// IC-7850 HF/6m 200W transceiver (predecessor to IC-7851)
    case ic7850 = "IC-7850"

    /// IC-7800 HF/6m 200W flagship transceiver (predecessor to IC-7850)
    case ic7800 = "IC-7800"

    /// IC-756 Pro III HF/6m 100W transceiver
    case ic756proIII = "IC-756 Pro III"

    /// IC-756 Pro II HF/6m 100W transceiver
    case ic756proII = "IC-756 Pro II"

    /// IC-756 Pro HF/6m 100W transceiver
    case ic756pro = "IC-756 Pro"

    /// IC-756 HF/6m 100W transceiver (original model)
    case ic756 = "IC-756"

    /// IC-746 Pro HF/6m/2m receive transceiver
    case ic746pro = "IC-746 Pro"

    /// IC-746 HF/6m/2m receive transceiver
    case ic746 = "IC-746"

    /// IC-7700 HF/6m 200W high-end transceiver
    case ic7700 = "IC-7700"

    /// IC-7410 HF/6m 100W transceiver
    case ic7410 = "IC-7410"

    /// IC-7400 HF/6m/2m 100W transceiver
    case ic7400 = "IC-7400"

    /// IC-7200 HF/6m 100W transceiver
    case ic7200 = "IC-7200"

    /// IC-735 HF all-mode transceiver (classic)
    case ic735 = "IC-735"

    /// IC-718 HF 100W transceiver (budget model)
    case ic718 = "IC-718"

    /// IC-706MKIIG HF/VHF/UHF mobile transceiver
    case ic706mkiig = "IC-706MKIIG"

    /// IC-706MKII HF/VHF mobile transceiver
    case ic706mkii = "IC-706MKII"

    /// IC-706 HF/VHF mobile transceiver
    case ic706 = "IC-706"

    // MARK: - HF/VHF/UHF Multi-band Transceivers

    /// IC-7100 HF/VHF/UHF 100W transceiver with D-STAR
    case ic7100 = "IC-7100"

    /// IC-9700 VHF/UHF/1.2GHz 100W transceiver with D-STAR and satellite mode
    case ic9700 = "IC-9700"

    /// IC-905 VHF/UHF/SHF all-mode transceiver with satellite mode
    case ic905 = "IC-905"

    /// IC-9100 HF/VHF/UHF 100W transceiver with D-STAR and satellite mode
    case ic9100 = "IC-9100"

    /// IC-705 Portable HF/VHF/UHF 10W transceiver with D-STAR
    case ic705 = "IC-705"

    /// IC-703 Portable HF/6m 10W QRP transceiver
    case ic703 = "IC-703"

    // MARK: - Xiegu Radios (CI-V Compatible)

    /// Xiegu G90 HF 20W SDR transceiver
    case xieguG90 = "Xiegu G90"

    /// Xiegu X6100 HF/6m 10W portable SDR transceiver
    case xieguX6100 = "Xiegu X6100"

    /// Xiegu X6200 HF/6m 8W portable SDR transceiver
    case xieguX6200 = "Xiegu X6200"

    // MARK: - VHF/UHF Transceivers

    /// IC-910H VHF/UHF all-mode transceiver with satellite mode
    case ic910h = "IC-910H"

    /// IC-9000 VHF/UHF all-mode transceiver
    case ic9000 = "IC-9000"

    /// IC-820H VHF/UHF all-mode transceiver
    case ic820h = "IC-820H"

    /// IC-275 2m all-mode transceiver
    case ic275 = "IC-275"

    /// IC-375 70cm all-mode transceiver
    case ic375 = "IC-375"

    /// IC-475 70cm all-mode transceiver
    case ic475 = "IC-475"

    // MARK: - Mobile/Base VHF/UHF FM Transceivers

    /// IC-2730 VHF/UHF dual-band FM mobile
    case ic2730 = "IC-2730"

    /// IC-2820H VHF/UHF dual-band FM mobile with D-STAR
    case ic2820h = "IC-2820H"

    /// IC-7000 HF/VHF/UHF 100W mobile transceiver
    case ic7000 = "IC-7000"

    /// ID-5100 VHF/UHF dual-band mobile with D-STAR
    case id5100 = "ID-5100"

    /// ID-4100 VHF/UHF dual-band mobile with D-STAR
    case id4100 = "ID-4100"

    // MARK: - Receivers

    /// IC-R8600 Wideband communications receiver
    case icr8600 = "IC-R8600"

    /// IC-R75 HF communications receiver
    case icr75 = "IC-R75"

    /// IC-R30 Handheld wideband receiver
    case icr30 = "IC-R30"

    /// IC-R9500 Professional wideband receiver
    case icr9500 = "IC-R9500"

    // MARK: - Properties

    /// Default CI-V address for this radio model
    ///
    /// Note: Users can change this on their radio, so always allow custom addresses.
    public var defaultCIVAddress: UInt8 {
        switch self {
        // HF Transceivers
        case .ic7600: return 0x7A
        case .ic7610: return 0x98
        case .ic7300: return 0x94
        case .ic7851: return 0x8E
        case .ic7850: return 0x8E
        case .ic7800: return 0x6A
        case .ic7700: return 0x74
        case .ic7410: return 0x80
        case .ic7400: return 0x66
        case .ic7200: return 0x76
        case .ic735: return 0x04
        case .ic718: return 0x5E
        case .ic756proIII: return 0x6E
        case .ic756proII: return 0x64
        case .ic756pro: return 0x5C
        case .ic756: return 0x50
        case .ic746pro: return 0x66
        case .ic746: return 0x56
        case .ic706mkiig: return 0x58
        case .ic706mkii: return 0x4E
        case .ic706: return 0x48

        // Multi-band
        case .ic7100: return 0x88
        case .ic9700: return 0xA2
        case .ic905: return 0xAC
        case .ic9100: return 0x7C
        case .ic705: return 0xA4
        case .ic703: return 0x68

        // Xiegu (CI-V compatible)
        case .xieguG90, .xieguX6100, .xieguX6200: return 0xA4

        // VHF/UHF
        case .ic910h: return 0x60
        case .ic9000: return 0x60  // Same as IC-910H
        case .ic820h: return 0x42
        case .ic275: return 0x10
        case .ic375: return 0x12
        case .ic475: return 0x14

        // Mobile/FM
        case .ic2730: return 0x90
        case .ic2820h: return 0x42
        case .ic7000: return 0x70
        case .id5100: return 0x8C
        case .id4100: return 0x9A

        // Receivers
        case .icr8600: return 0x96
        case .icr75: return 0x5A
        case .icr30: return 0x9C
        case .icr9500: return 0x72
        }
    }

    /// Human-readable description
    public var description: String {
        rawValue
    }

    /// Whether this radio supports D-STAR digital voice
    public var supportsDSTAR: Bool {
        switch self {
        case .ic7100, .ic9700, .ic9100, .ic705, .ic2820h, .id4100, .id5100:
            return true
        default:
            return false
        }
    }

    /// Whether this radio supports satellite operation
    public var supportsSatellite: Bool {
        switch self {
        case .ic9700, .ic9100, .ic910h:
            return true
        default:
            return false
        }
    }

    /// Whether this radio has dual receivers
    public var hasDualReceiver: Bool {
        switch self {
        case .ic7600, .ic7610, .ic7851, .ic7850, .ic7800, .ic756, .ic756pro, .ic756proII, .ic756proIII,
             .ic9700, .ic9100, .ic910h, .ic2730, .ic2820h, .id4100, .id5100:
            return true
        default:
            return false
        }
    }

    /// Whether this radio has spectrum scope capability
    public var hasSpectrumScope: Bool {
        switch self {
        case .ic7610, .ic7300, .ic9700, .ic7851:
            return true
        default:
            return false
        }
    }
}
