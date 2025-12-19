import Foundation

/// IF (Intermediate Frequency) filter selection for receive filtering.
///
/// Modern Icom radios have multiple selectable IF filters that determine the receiver bandwidth.
/// These filters help reduce adjacent channel interference and improve signal-to-noise ratio.
///
/// ## Filter Selection
///
/// Most Icom radios have 3 filter positions (FIL1, FIL2, FIL3) with different characteristics:
/// - **FIL1**: Typically the widest filter (default for each mode)
/// - **FIL2**: Medium width filter
/// - **FIL3**: Narrowest filter for weak signal work
///
/// Each mode (SSB, CW, RTTY, etc.) has independent filter settings stored in the radio.
///
/// ## Radio Support
///
/// - **IC-7600, IC-7300, IC-7610, IC-7851, IC-7800, IC-7700**: Full filter control
/// - **IC-9700, IC-9100**: Full filter control with DSP
/// - **IC-7100, IC-705**: Simplified filter control
///
/// ## Usage
/// ```swift
/// // Select narrow filter for CW
/// try await rig.setIFFilter(.filter3)
///
/// // Select default filter
/// try await rig.setIFFilter(.filter1)
///
/// // Get current filter
/// let filter = try await rig.ifFilter()
/// print("Current filter: \(filter.description)")
/// ```
///
/// ## Technical Details
///
/// The filter selection is sent with the mode command in modern Icom radios.
/// The actual bandwidth of each filter varies by mode and can be customized
/// in the radio's menu settings.
///
/// ### Example Bandwidths (IC-7600 SSB mode defaults)
/// - FIL1: 2.4 kHz (wide)
/// - FIL2: 1.8 kHz (medium)
/// - FIL3: 1.2 kHz (narrow)
///
/// ### Example Bandwidths (IC-7600 CW mode defaults)
/// - FIL1: 600 Hz (wide)
/// - FIL2: 300 Hz (medium)
/// - FIL3: 100 Hz (narrow)
public enum IFFilter: UInt8, Sendable, Codable, CaseIterable, CustomStringConvertible {
    /// Filter 1 - Widest filter (default for most modes)
    case filter1 = 0x01

    /// Filter 2 - Medium width filter
    case filter2 = 0x02

    /// Filter 3 - Narrowest filter
    case filter3 = 0x03

    /// Human-readable description
    public var description: String {
        switch self {
        case .filter1:
            return "FIL1 (Wide)"
        case .filter2:
            return "FIL2 (Medium)"
        case .filter3:
            return "FIL3 (Narrow)"
        }
    }

    /// Short name for display
    public var shortName: String {
        switch self {
        case .filter1: return "FIL1"
        case .filter2: return "FIL2"
        case .filter3: return "FIL3"
        }
    }

    /// Relative width descriptor
    public var width: FilterWidth {
        switch self {
        case .filter1: return .wide
        case .filter2: return .medium
        case .filter3: return .narrow
        }
    }
}

/// Relative filter width descriptor.
///
/// Describes the relative width of a filter without specifying exact bandwidth,
/// since actual bandwidths vary by radio model and mode.
public enum FilterWidth: String, Sendable, Codable, CustomStringConvertible {
    /// Wide filter - maximum bandwidth, best for strong signals
    case wide = "Wide"

    /// Medium filter - balanced bandwidth
    case medium = "Medium"

    /// Narrow filter - minimum bandwidth, best for weak signals and QRM reduction
    case narrow = "Narrow"

    public var description: String {
        rawValue
    }
}

/// Advanced IF filter configuration for radios that support bandwidth customization.
///
/// Some radios (like IC-7600) allow setting exact filter bandwidths using an index value.
/// This is a more advanced feature and not all radios support it.
///
/// ## Usage
/// ```swift
/// // Set custom filter width by index (IC-7600)
/// if let icomProtocol = rig.protocol as? IcomCIVProtocol {
///     try await icomProtocol.setFilterWidthIC7600(25)  // Index 0-49
/// }
/// ```
public struct IFFilterConfig: Sendable, Equatable {
    /// Filter selection (FIL1/FIL2/FIL3)
    public var filter: IFFilter

    /// Optional custom width index for radios that support it (0-49)
    /// - Note: Only supported on some radios (IC-7600, etc.)
    public var widthIndex: UInt8?

    /// Initialize with filter selection
    public init(filter: IFFilter, widthIndex: UInt8? = nil) {
        self.filter = filter
        self.widthIndex = widthIndex
    }

    /// Preset: Wide filter (FIL1)
    public static let wide = IFFilterConfig(filter: .filter1)

    /// Preset: Medium filter (FIL2)
    public static let medium = IFFilterConfig(filter: .filter2)

    /// Preset: Narrow filter (FIL3)
    public static let narrow = IFFilterConfig(filter: .filter3)
}
