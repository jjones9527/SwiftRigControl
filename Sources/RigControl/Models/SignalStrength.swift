import Foundation

/// Represents radio signal strength in S-units
///
/// S-units are the standard way of measuring signal strength in amateur radio:
/// - S0 to S9 represent standard signal levels
/// - Values above S9 are expressed as "S9 plus decibels" (e.g., S9+20)
/// - Each S-unit below S9 represents approximately 6 dB
/// - Above S9, decibels are measured directly
///
/// # Usage Example
/// ```swift
/// let signal = try await rig.signalStrength()
/// print(signal.description)  // "S7" or "S9+20"
///
/// if signal.sUnits >= 7 {
///     print("Good signal strength")
/// }
/// ```
public struct SignalStrength: Sendable, Equatable, CustomStringConvertible {

    /// S-units (0-9), where S9 is the strongest standard reading
    ///
    /// Values are automatically clamped to 0-9 range.
    public let sUnits: Int

    /// Decibels over S9 (0-60), used when signal exceeds S9
    ///
    /// Only meaningful when `sUnits == 9`. Values are automatically clamped to 0-60 range.
    public let overS9: Int

    /// Raw protocol-specific value for debugging
    ///
    /// This is the unprocessed value from the radio's protocol.
    /// Useful for troubleshooting and comparing different radio implementations.
    public let raw: Int

    /// Human-readable description (e.g., "S5", "S9+20")
    public var description: String {
        if sUnits < 9 {
            return "S\(sUnits)"
        } else {
            return "S9+\(overS9)"
        }
    }

    /// Initialize from S-units and over-S9 value
    ///
    /// - Parameters:
    ///   - sUnits: Signal strength in S-units (0-9, will be clamped)
    ///   - overS9: Decibels over S9 (0-60, will be clamped)
    ///   - raw: Raw protocol-specific value
    ///
    /// # Example
    /// ```swift
    /// // S5 signal
    /// let weak = SignalStrength(sUnits: 5, raw: 120)
    ///
    /// // S9+20 signal
    /// let strong = SignalStrength(sUnits: 9, overS9: 20, raw: 236)
    /// ```
    public init(sUnits: Int, overS9: Int = 0, raw: Int) {
        self.sUnits = max(0, min(9, sUnits))
        self.overS9 = max(0, min(60, overS9))
        self.raw = raw
    }

    /// Approximate signal strength in decibels over S0
    ///
    /// This provides a linear representation of signal strength:
    /// - S0 = 0 dB
    /// - S9 = 54 dB (6 dB per S-unit)
    /// - S9+20 = 74 dB
    public var decibels: Int {
        if sUnits < 9 {
            return sUnits * 6
        } else {
            return 54 + overS9
        }
    }

    /// Returns true if signal is at or above S9
    public var isStrongSignal: Bool {
        return sUnits == 9
    }

    /// Returns true if signal is below S3 (very weak)
    public var isWeakSignal: Bool {
        return sUnits < 3
    }
}

// MARK: - Comparable

extension SignalStrength: Comparable {
    public static func < (lhs: SignalStrength, rhs: SignalStrength) -> Bool {
        return lhs.decibels < rhs.decibels
    }
}

// MARK: - Codable

extension SignalStrength: Codable {
    enum CodingKeys: String, CodingKey {
        case sUnits
        case overS9
        case raw
    }
}
