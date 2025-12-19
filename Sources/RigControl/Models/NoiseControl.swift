import Foundation

/// Noise blanker configuration.
///
/// Noise blanker (NB) removes impulse noise such as:
/// - Power line noise
/// - Ignition noise from vehicles
/// - Electric fence pulses
/// - Static crashes
///
/// ## Radio Support
///
/// Different Icom models have different NB capabilities:
/// - **IC-9700, IC-7100**: NB with level control (0-10)
/// - **IC-7600, IC-7300, IC-7610**: NB on/off only
/// - **IC-705**: NB with level control
///
/// ## Usage
/// ```swift
/// // Enable NB with level 5
/// try await rig.setNoiseBlanker(.enabled(level: 5))
///
/// // Disable NB
/// try await rig.setNoiseBlanker(.off)
///
/// // Enable NB (radios without level control)
/// try await rig.setNoiseBlanker(.enabled())
/// ```
public enum NoiseBlanker: Sendable, Equatable {
    /// Noise blanker off
    case off

    /// Noise blanker enabled with optional level
    /// - Parameter level: NB depth/level (0-10 for radios that support it, nil for simple on/off)
    case enabled(level: Int? = nil)

    /// Human-readable description
    public var description: String {
        switch self {
        case .off:
            return "NB Off"
        case .enabled(let level):
            if let level = level {
                return "NB Level \(level)"
            } else {
                return "NB On"
            }
        }
    }

    /// Whether NB is enabled
    public var isEnabled: Bool {
        switch self {
        case .off: return false
        case .enabled: return true
        }
    }

    /// NB level (0-10), nil if off or level not supported
    public var level: Int? {
        switch self {
        case .off: return nil
        case .enabled(let level): return level
        }
    }
}

/// Noise reduction configuration.
///
/// Noise reduction (NR) reduces continuous background noise such as:
/// - Atmospheric noise
/// - Band noise
/// - Receiver noise
/// - QRM (interference)
///
/// NR uses DSP filtering to reduce noise while preserving the desired signal.
///
/// ## Radio Support
///
/// Different Icom models have different NR capabilities:
/// - **IC-9700**: NR with level control (0-15 or 0-255 depending on firmware)
/// - **IC-7100**: NR with level control (0-15)
/// - **IC-7600, IC-7300, IC-7610**: NR with level control (0-10 or 0-15)
/// - **IC-705**: NR with level control (0-10)
///
/// ## Usage
/// ```swift
/// // Enable NR with level 8
/// try await rig.setNoiseReduction(.enabled(level: 8))
///
/// // Disable NR
/// try await rig.setNoiseReduction(.off)
///
/// // Maximum NR for weak signal work
/// try await rig.setNoiseReduction(.enabled(level: 15))
/// ```
///
/// ## Trade-offs
/// Higher NR levels provide better noise reduction but may:
/// - Reduce audio fidelity
/// - Introduce latency
/// - Affect signal intelligibility
/// - Remove high-frequency components
///
/// For best results, use the minimum NR level that provides acceptable noise reduction.
public enum NoiseReduction: Sendable, Equatable {
    /// Noise reduction off
    case off

    /// Noise reduction enabled with level
    /// - Parameter level: NR depth/strength (0-15 typical, some radios use 0-255)
    case enabled(level: Int)

    /// Human-readable description
    public var description: String {
        switch self {
        case .off:
            return "NR Off"
        case .enabled(let level):
            return "NR Level \(level)"
        }
    }

    /// Whether NR is enabled
    public var isEnabled: Bool {
        switch self {
        case .off: return false
        case .enabled: return true
        }
    }

    /// NR level (0-15 or 0-255), nil if off
    public var level: Int? {
        switch self {
        case .off: return nil
        case .enabled(let level): return level
        }
    }
}

/// Combined noise control configuration.
///
/// Some applications may want to configure both NB and NR together.
/// This type provides a convenient way to represent the complete noise control state.
///
/// ## Usage
/// ```swift
/// // Configure both NB and NR
/// let noiseConfig = NoiseControlConfig(
///     blanker: .enabled(level: 5),
///     reduction: .enabled(level: 10)
/// )
///
/// // Apply to radio
/// try await rig.setNoiseBlanker(noiseConfig.blanker)
/// try await rig.setNoiseReduction(noiseConfig.reduction)
/// ```
public struct NoiseControlConfig: Sendable, Equatable {
    /// Noise blanker configuration
    public var blanker: NoiseBlanker

    /// Noise reduction configuration
    public var reduction: NoiseReduction

    /// Initialize with specific NB and NR settings
    public init(blanker: NoiseBlanker, reduction: NoiseReduction) {
        self.blanker = blanker
        self.reduction = reduction
    }

    /// Both NB and NR off
    public static let off = NoiseControlConfig(
        blanker: .off,
        reduction: .off
    )

    /// Light noise reduction (NB level 3, NR level 5)
    public static let light = NoiseControlConfig(
        blanker: .enabled(level: 3),
        reduction: .enabled(level: 5)
    )

    /// Medium noise reduction (NB level 5, NR level 8)
    public static let medium = NoiseControlConfig(
        blanker: .enabled(level: 5),
        reduction: .enabled(level: 8)
    )

    /// Heavy noise reduction (NB level 8, NR level 12)
    public static let heavy = NoiseControlConfig(
        blanker: .enabled(level: 8),
        reduction: .enabled(level: 12)
    )
}
