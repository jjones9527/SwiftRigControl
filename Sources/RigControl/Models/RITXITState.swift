import Foundation

/// Represents the state of RIT (Receiver Incremental Tuning) or XIT (Transmitter Incremental Tuning).
///
/// RIT and XIT allow fine-tuning of the receiver or transmitter frequency independently
/// from the displayed VFO frequency. This is useful for:
/// - Split operation in contests and DX work
/// - Zero-beating CW signals
/// - Compensating for slight frequency offsets
///
/// ## Usage
///
/// ```swift
/// // Enable RIT with +500 Hz offset
/// let ritState = RITXITState(enabled: true, offset: 500)
/// try await rig.setRIT(ritState)
///
/// // Disable RIT
/// try await rig.setRIT(RITXITState(enabled: false, offset: 0))
///
/// // Read current RIT state
/// let currentRIT = try await rig.getRIT()
/// print("RIT: \(currentRIT.enabled ? "ON" : "OFF"), Offset: \(currentRIT.offset) Hz")
/// ```
///
/// ## Typical Range
/// Most radios support offsets between -9999 Hz and +9999 Hz, though this varies by manufacturer.
/// Check your radio's capabilities before setting extreme values.
public struct RITXITState: Sendable, Equatable, Codable {
    /// Whether RIT/XIT is enabled
    public let enabled: Bool

    /// Frequency offset in Hz (typically -9999 to +9999)
    ///
    /// Positive values shift the frequency higher, negative values shift lower.
    /// The offset is applied to the receive frequency (RIT) or transmit frequency (XIT).
    public let offset: Int

    /// Creates a new RIT/XIT state
    ///
    /// - Parameters:
    ///   - enabled: Whether RIT/XIT should be enabled
    ///   - offset: Frequency offset in Hz (default: 0)
    public init(enabled: Bool, offset: Int = 0) {
        self.enabled = enabled
        self.offset = offset
    }

    /// Convenience initializer for disabled state
    public static let disabled = RITXITState(enabled: false, offset: 0)

    /// A human-readable description of the state
    public var description: String {
        if enabled {
            let sign = offset >= 0 ? "+" : ""
            return "ON (\(sign)\(offset) Hz)"
        } else {
            return "OFF"
        }
    }
}

// MARK: - CustomStringConvertible

extension RITXITState: CustomStringConvertible {}
