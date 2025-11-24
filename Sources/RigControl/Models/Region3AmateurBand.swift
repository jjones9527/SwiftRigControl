import Foundation

/// Amateur radio band allocations for ITU Region 3 (Asia-Pacific).
///
/// These bands represent the frequency allocations defined by IARU Region 3 and international
/// regulations for amateur radio operations in the Asia-Pacific region.
///
/// Region 3 includes: Asia (excluding Middle East and Northern Asia), Australia, New Zealand,
/// and Pacific Islands
///
/// Key differences from Region 2:
/// - 80m: 3.5-3.9 MHz (narrower than Region 2)
/// - 40m: 7.0-7.3 MHz (same as Region 2 for most countries)
/// - 60m: Varies by country, often not allocated
///
/// Reference: https://www.iaru-r3.org/
public enum Region3AmateurBand: String, CaseIterable, Sendable, AmateurBandProtocol {
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
    case band70cm = "70cm"
    case band23cm = "23cm"

    /// Frequency range for this band in Hz
    ///
    /// These ranges represent the legal amateur radio allocations in Region 3.
    /// Note: Transmit privileges may vary based on license class and country.
    public var frequencyRange: ClosedRange<UInt64> {
        switch self {
        case .band2200m:
            return 135_700...137_800
        case .band630m:
            return 472_000...479_000
        case .band160m:
            return 1_800_000...2_000_000
        case .band80m:
            return 3_500_000...3_900_000  // Between Region 1 and Region 2
        case .band60m:
            return 5_351_500...5_366_500  // Limited availability in Region 3
        case .band40m:
            return 7_000_000...7_300_000  // Same as Region 2 for most countries
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
            return 50_000_000...54_000_000
        case .band2m:
            return 144_000_000...148_000_000
        case .band70cm:
            return 430_000_000...450_000_000
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
            // 60m - USB only, limited availability
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

        case .band2m, .band70cm, .band23cm:
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
    /// - Returns: The `Region3AmateurBand` containing this frequency, or `nil` if not in an amateur band
    public static func band(for frequency: UInt64) -> Region3AmateurBand? {
        return Region3AmateurBand.allCases.first { $0.contains(frequency) }
    }

    /// Get the wavelength designation for display
    public var wavelength: String {
        rawValue
    }
}
