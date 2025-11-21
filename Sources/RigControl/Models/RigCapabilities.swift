import Foundation

/// Represents a frequency range for a radio transceiver.
public struct FrequencyRange: Sendable, Codable, Equatable {
    /// Minimum frequency in Hz
    public let min: UInt64

    /// Maximum frequency in Hz
    public let max: UInt64

    public init(min: UInt64, max: UInt64) {
        self.min = min
        self.max = max
    }
}

/// Describes the capabilities of a specific radio model.
///
/// Different radios support different features. This structure allows the library
/// to query what operations are supported before attempting them.
public struct RigCapabilities: Sendable, Codable {
    /// Radio supports a second VFO (VFO B)
    public let hasVFOB: Bool

    /// Radio supports split operation (transmit on VFO B, receive on VFO A)
    public let hasSplit: Bool

    /// Radio supports RF power level control
    public let powerControl: Bool

    /// Maximum transmit power in watts
    public let maxPower: Int

    /// Supported operating modes
    public let supportedModes: Set<Mode>

    /// Frequency range in Hz (min, max)
    public let frequencyRange: FrequencyRange?

    /// Radio has dual receivers (main/sub)
    public let hasDualReceiver: Bool

    /// Radio supports antenna tuner control
    public let hasATU: Bool

    /// Radio supports S-meter signal strength reading
    public let supportsSignalStrength: Bool

    public init(
        hasVFOB: Bool = true,
        hasSplit: Bool = true,
        powerControl: Bool = true,
        maxPower: Int = 100,
        supportedModes: Set<Mode> = Set(Mode.allCases),
        frequencyRange: FrequencyRange? = nil,
        hasDualReceiver: Bool = false,
        hasATU: Bool = false,
        supportsSignalStrength: Bool = true
    ) {
        self.hasVFOB = hasVFOB
        self.hasSplit = hasSplit
        self.powerControl = powerControl
        self.maxPower = maxPower
        self.supportedModes = supportedModes
        self.frequencyRange = frequencyRange
        self.hasDualReceiver = hasDualReceiver
        self.hasATU = hasATU
        self.supportsSignalStrength = supportsSignalStrength
    }

    /// Full-featured radio capabilities (for high-end transceivers)
    public static let full = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: Set(Mode.allCases),
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true
    )

    /// Basic radio capabilities (for simple transceivers)
    public static let basic = RigCapabilities(
        hasVFOB: false,
        hasSplit: false,
        powerControl: false,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .fm],
        frequencyRange: nil,
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: false
    )
}
