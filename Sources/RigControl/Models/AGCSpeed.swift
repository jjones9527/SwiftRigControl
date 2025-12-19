import Foundation

/// Automatic Gain Control (AGC) speed settings.
///
/// AGC controls how quickly the receiver responds to changes in signal strength.
/// Different speeds are optimal for different operating modes and conditions.
///
/// ## Usage Recommendations
///
/// - **Fast**: Best for CW and digital modes where rapid signal changes occur
/// - **Medium**: Good general-purpose setting for SSB and mixed modes
/// - **Slow**: Preferred for weak signal SSB work and DXing
/// - **Off**: Disables AGC for manual gain control (advanced users only)
///
/// ## Radio Support
///
/// Not all radios support all AGC speeds:
/// - IC-7600, IC-7300, IC-7610: Fast, Medium, Slow (no Off)
/// - IC-9700, IC-7100, IC-705: Off, Fast, Medium, Slow
/// - FTDX-10, FTDX-101: Off, Fast, Medium, Slow, Auto
/// - TS-890S: Off, Fast, Medium, Slow
///
/// When setting an unsupported mode, the radio will either:
/// - Use the closest supported mode
/// - Return an error (radio-dependent)
public enum AGCSpeed: String, Sendable, Codable, CaseIterable {
    /// AGC disabled (manual RF gain control)
    ///
    /// When AGC is off, the operator must manually adjust RF gain to prevent
    /// overload and optimize signal-to-noise ratio. This requires constant
    /// adjustment as signal conditions change.
    case off = "OFF"

    /// Fast AGC response
    ///
    /// Responds quickly to signal changes. Optimal for:
    /// - CW (Morse code)
    /// - Digital modes (RTTY, PSK31, FT8)
    /// - Contest operation with rapid QSY
    ///
    /// Typical time constant: 20-100ms attack, 100-300ms decay
    case fast = "FAST"

    /// Medium AGC response
    ///
    /// Balanced response speed. Optimal for:
    /// - General SSB operation
    /// - AM broadcast reception
    /// - Mixed-mode operation
    ///
    /// Typical time constant: 100-300ms attack, 500-1000ms decay
    case medium = "MEDIUM"

    /// Slow AGC response
    ///
    /// Gradual response to signal changes. Optimal for:
    /// - Weak signal SSB DXing
    /// - QRP operation
    /// - Reducing pumping effect on fading signals
    ///
    /// Typical time constant: 500-1000ms attack, 2-5s decay
    case slow = "SLOW"

    /// Automatic AGC selection (radio-dependent)
    ///
    /// Some radios automatically select AGC speed based on operating mode:
    /// - CW mode → Fast AGC
    /// - SSB mode → Medium or Slow AGC
    /// - AM mode → Fast or Medium AGC
    ///
    /// Only supported on select Yaesu radios (FTDX-10, FTDX-101).
    case auto = "AUTO"

    /// Human-readable description
    public var description: String {
        switch self {
        case .off:
            return "AGC Off"
        case .fast:
            return "Fast AGC"
        case .medium:
            return "Medium AGC"
        case .slow:
            return "Slow AGC"
        case .auto:
            return "Auto AGC"
        }
    }

    /// Typical attack time in milliseconds (approximate)
    public var attackTime: Int {
        switch self {
        case .off: return 0
        case .fast: return 50
        case .medium: return 200
        case .slow: return 750
        case .auto: return 200  // Varies by mode
        }
    }

    /// Typical decay time in milliseconds (approximate)
    public var decayTime: Int {
        switch self {
        case .off: return 0
        case .fast: return 200
        case .medium: return 750
        case .slow: return 3500
        case .auto: return 750  // Varies by mode
        }
    }
}
