import Foundation

/// Amateur radio band allocations for ITU Region 1 (Europe, Africa, Middle East, Northern Asia).
///
/// These bands represent the frequency allocations defined by IARU Region 1 and international
/// regulations for amateur radio operations in Europe, Africa, the Middle East, and Northern Asia.
///
/// Region 1 includes: Europe, Africa, Middle East, Russia, and Northern Asia
///
/// Key differences from Region 2:
/// - 80m: 3.5-3.8 MHz (narrower)
/// - 60m: 5.3515-5.3665 MHz (different allocation)
/// - 40m: 7.0-7.2 MHz (narrower)
///
/// Reference: https://www.iaru-r1.org/
public enum Region1AmateurBand: String, CaseIterable, Sendable, AmateurBandProtocol {
    case band2200m = "2200m"
    case band630m = "630m"
    case band160m = "160m"
    case band80m = "80m"
    case band60m = "60m"
    case band40m = "40m"
    case band30m = "30m"
    case band20m = "20m"
    case band17m = "17m"
    case band15m = "15m"
    case band12m = "12m"
    case band10m = "10m"
    case band6m = "6m"
    case band2m = "2m"
    case band1_25m = "1.25m"
    case band70cm = "70cm"
    case band23cm = "23cm"

    /// Frequency range for this band in Hz
    ///
    /// These ranges represent the legal amateur radio allocations in Region 1.
    /// Note: Transmit privileges may vary based on license class.
    public var frequencyRange: ClosedRange<UInt64> {
        switch self {
        case .band2200m:
            return 135_700...137_800
        case .band630m:
            return 472_000...479_000
        case .band160m:
            return 1_810_000...2_000_000
        case .band80m:
            return 3_500_000...3_800_000  // Narrower than Region 2
        case .band60m:
            return 5_351_500...5_366_500  // Different allocation than Region 2
        case .band40m:
            return 7_000_000...7_200_000  // Narrower than Region 2
        case .band30m:
            return 10_100_000...10_150_000
        case .band20m:
            return 14_000_000...14_350_000
        case .band17m:
            return 18_068_000...18_168_000
        case .band15m:
            return 21_000_000...21_450_000
        case .band12m:
            return 24_890_000...24_990_000
        case .band10m:
            return 28_000_000...29_700_000
        case .band6m:
            return 50_000_000...52_000_000  // Some Region 1 countries have 50-52 MHz
        case .band2m:
            return 144_000_000...146_000_000  // Narrower than Region 2
        case .band1_25m:
            return 222_000_000...225_000_000  // Not available in all Region 1 countries
        case .band70cm:
            return 430_000_000...440_000_000  // Narrower than Region 2
        case .band23cm:
            return 1_240_000_000...1_300_000_000
        }
    }

    /// Common modes used on this band
    ///
    /// These represent typical operating modes used by amateurs on each band.
    /// Note: Actual allowed modes may vary; consult current band plans.
    public var commonModes: Set<Mode> {
        switch self {
        case .band2200m, .band630m:
            // LF/MF bands - primarily CW and digital modes (USB carrier for digital)
            return [.cw, .usb]

        case .band160m, .band80m:
            // Lower HF bands - LSB for voice below 10 MHz, CW, and digital
            return [.lsb, .cw, .rtty, .usb, .am]

        case .band60m:
            // 60m - USB only, limited channels in Region 1
            return [.usb, .cw]

        case .band40m:
            // 40m - LSB for voice, CW, and digital
            return [.lsb, .cw, .rtty, .usb]

        case .band30m:
            // 30m - CW and digital only (no phone)
            return [.cw, .usb]

        case .band20m, .band17m, .band15m, .band12m:
            // Upper HF bands - USB for voice above 10 MHz
            return [.usb, .cw, .rtty, .am]

        case .band10m:
            // 10m - USB, CW, FM, AM
            return [.usb, .cw, .rtty, .am, .fm]

        case .band6m:
            // 6m - USB, CW, FM (similar to 10m)
            return [.usb, .cw, .fm]

        case .band2m, .band1_25m, .band70cm, .band23cm:
            // VHF/UHF bands - primarily FM, with SSB and CW
            return [.fm, .usb, .cw]
        }
    }

    /// Display name for the band
    public var displayName: String {
        rawValue
    }

    /// Check if a frequency is within this band
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: `true` if the frequency is within this amateur band
    public func contains(_ frequency: UInt64) -> Bool {
        return frequencyRange.contains(frequency)
    }

    /// Get the amateur band for a given frequency
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: The `Region1AmateurBand` containing this frequency, or `nil` if not in an amateur band
    public static func band(for frequency: UInt64) -> Region1AmateurBand? {
        return Region1AmateurBand.allCases.first { $0.contains(frequency) }
    }

    /// Get the wavelength designation for display
    public var wavelength: String {
        rawValue
    }
}
