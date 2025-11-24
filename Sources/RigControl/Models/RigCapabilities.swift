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

/// Represents a detailed frequency range with mode and transmit capability information.
public struct DetailedFrequencyRange: Sendable, Codable, Equatable {
    /// Minimum frequency in Hz
    public let min: UInt64

    /// Maximum frequency in Hz
    public let max: UInt64

    /// Operating modes supported in this frequency range
    public let modes: Set<Mode>

    /// Whether the radio can transmit in this frequency range
    public let canTransmit: Bool

    /// Band name (e.g., "160m", "80m", "40m", "20m")
    public let bandName: String?

    public init(min: UInt64, max: UInt64, modes: Set<Mode>, canTransmit: Bool, bandName: String? = nil) {
        self.min = min
        self.max = max
        self.modes = modes
        self.canTransmit = canTransmit
        self.bandName = bandName
    }

    /// Check if a frequency is within this range
    public func contains(_ frequency: UInt64) -> Bool {
        return frequency >= min && frequency <= max
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
    /// - Note: For detailed frequency ranges with transmit capabilities, use `detailedFrequencyRanges`
    public let frequencyRange: FrequencyRange?

    /// Detailed frequency ranges with mode and transmit capability information
    public let detailedFrequencyRanges: [DetailedFrequencyRange]

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
        detailedFrequencyRanges: [DetailedFrequencyRange] = [],
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
        self.detailedFrequencyRanges = detailedFrequencyRanges
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

// MARK: - Frequency Validation

public extension RigCapabilities {
    /// Check if a frequency is valid for this radio (within any receive or transmit range)
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: `true` if the frequency is within the radio's capabilities
    func isFrequencyValid(_ frequency: UInt64) -> Bool {
        // If no detailed ranges, fall back to basic frequencyRange check
        if detailedFrequencyRanges.isEmpty {
            return frequencyRange?.min ?? 0 <= frequency && frequency <= frequencyRange?.max ?? UInt64.max
        }

        return detailedFrequencyRanges.contains { $0.contains(frequency) }
    }

    /// Check if the radio can transmit on a given frequency
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: `true` if the radio can transmit on this frequency
    func canTransmit(on frequency: UInt64) -> Bool {
        // If no detailed ranges, assume can transmit if frequency is valid
        if detailedFrequencyRanges.isEmpty {
            return isFrequencyValid(frequency)
        }

        return detailedFrequencyRanges.first { $0.contains(frequency) }?.canTransmit ?? false
    }

    /// Get supported modes for a specific frequency
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Set of modes supported at this frequency, or all supported modes if not specified
    func supportedModes(for frequency: UInt64) -> Set<Mode> {
        // If no detailed ranges, return all supported modes
        if detailedFrequencyRanges.isEmpty {
            return supportedModes
        }

        return detailedFrequencyRanges.first { $0.contains(frequency) }?.modes ?? []
    }

    /// Get band name for a frequency (e.g., "40m", "20m")
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Band name if available, otherwise `nil`
    func bandName(for frequency: UInt64) -> String? {
        return detailedFrequencyRanges.first { $0.contains(frequency) }?.bandName
    }

    /// Get the detailed frequency range that contains the given frequency
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: The `DetailedFrequencyRange` containing this frequency, or `nil` if not found
    func frequencyRange(containing frequency: UInt64) -> DetailedFrequencyRange? {
        return detailedFrequencyRanges.first { $0.contains(frequency) }
    }
}
