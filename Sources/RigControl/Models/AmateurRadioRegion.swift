import Foundation

/// ITU amateur radio regions for frequency allocations.
///
/// The International Telecommunication Union (ITU) divides the world into three regions
/// for the purpose of managing frequency allocations, including amateur radio bands.
///
/// - Region 1: Europe, Africa, Middle East, Northern Asia
/// - Region 2: The Americas (North and South America)
/// - Region 3: Asia-Pacific (excluding Middle East and Northern Asia)
///
/// Reference: https://www.itu.int/en/ITU-R/terrestrial/Pages/default.aspx
public enum AmateurRadioRegion: String, Sendable, Codable, CaseIterable {
    /// Region 1: Europe, Africa, Middle East, Northern Asia
    case region1 = "Region 1"

    /// Region 2: The Americas (North and South America)
    case region2 = "Region 2"

    /// Region 3: Asia-Pacific
    case region3 = "Region 3"

    /// Display name for the region
    public var displayName: String {
        rawValue
    }

    /// Geographic description
    public var geographicDescription: String {
        switch self {
        case .region1:
            return "Europe, Africa, Middle East, Northern Asia"
        case .region2:
            return "The Americas"
        case .region3:
            return "Asia-Pacific"
        }
    }
}

/// Protocol for amateur radio band allocations across different ITU regions.
///
/// This protocol allows different region-specific band implementations while
/// providing a common interface for frequency validation and band lookup.
public protocol AmateurBandProtocol: CaseIterable, Sendable {
    /// Frequency range for this band in Hz
    var frequencyRange: ClosedRange<UInt64> { get }

    /// Common modes used on this band
    var commonModes: Set<Mode> { get }

    /// Display name for the band (e.g., "20m", "40m")
    var displayName: String { get }

    /// Check if a frequency is within this band
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: `true` if the frequency is within this band
    func contains(_ frequency: UInt64) -> Bool

    /// Get the wavelength designation for display
    var wavelength: String { get }
}

/// Default implementation for AmateurBandProtocol
public extension AmateurBandProtocol {
    func contains(_ frequency: UInt64) -> Bool {
        return frequencyRange.contains(frequency)
    }
}
