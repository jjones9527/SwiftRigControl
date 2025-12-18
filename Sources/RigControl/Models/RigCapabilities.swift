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

/// Power control units used by different radio manufacturers.
///
/// **Research findings (2025-12-09):**
/// - **All Icom radios use percentage (0-100%)** - Confirmed via Hamlib GitHub issue #533
/// - IC-7100, IC-705, IC-9700, IC-7300, IC-7610 all display power as percentage
/// - The CI-V command 0x14 0x0A uses BCD scale 0-255 representing 0-100%
/// - This is independent of the radio's actual max power output
public enum PowerUnits: Sendable, Codable, Equatable {
    /// Power specified as percentage (0-100%)
    /// Used by all Icom radios (IC-7100, IC-705, IC-9700, IC-7300, IC-7610, etc.)
    case percentage

    /// Power specified in watts (0 to max watts)
    /// Used by some manufacturers (Yaesu, Kenwood, Elecraft)
    case watts(max: Int)

    /// Convert user input (percentage or watts) to BCD scale (0-255) for CI-V
    /// - Parameter value: Power value in percentage (0-100) or watts depending on unit type
    /// - Returns: BCD scale value (0-255)
    public func toScale(_ value: Int) -> Int {
        switch self {
        case .percentage:
            // For percentage radios: 0-100% maps to 0-255
            let clamped = min(max(value, 0), 100)
            return (clamped * 255) / 100
        case .watts(let maxPower):
            // For watt-based radios: 0-maxWatts maps to 0-255
            let clamped = min(max(value, 0), maxPower)
            return (clamped * 255) / maxPower
        }
    }

    /// Convert BCD scale (0-255) from CI-V to user-facing value
    /// - Parameter scale: BCD scale value (0-255)
    /// - Returns: Power value in percentage (0-100) or watts depending on unit type
    public func fromScale(_ scale: Int) -> Int {
        switch self {
        case .percentage:
            // For percentage radios: 0-255 maps to 0-100%
            return (scale * 100) / 255
        case .watts(let maxPower):
            // For watt-based radios: 0-255 maps to 0-maxWatts
            return (scale * maxPower) / 255
        }
    }

    /// Display unit suffix for UI
    public var displayUnit: String {
        switch self {
        case .percentage:
            return "%"
        case .watts:
            return "W"
        }
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

    /// Radio requires explicit VFO selection before frequency/mode commands
    /// Some radios (like IC-7100, IC-705) don't require/support the VFO select command (0x07)
    /// and will NAK it. For these radios, set this to false.
    public let requiresVFOSelection: Bool

    /// Radio requires filter byte in mode set command (0x06)
    /// Some radios (like IC-7100, IC-705) reject mode commands that include a filter byte.
    /// For these radios, set this to false and only send the mode byte.
    public let requiresModeFilter: Bool

    /// Power control units (percentage vs watts)
    /// - All Icom radios use `.percentage`
    /// - Other manufacturers may use `.watts(max: X)`
    public let powerUnits: PowerUnits

    /// ITU region for amateur band validation (defaults to Region 2)
    public let region: AmateurRadioRegion

    /// Radio supports RIT (Receiver Incremental Tuning)
    /// Most modern transceivers support RIT
    public let supportsRIT: Bool

    /// Radio supports XIT (Transmitter Incremental Tuning)
    /// Some radios only support RIT (affects both RX/TX), not separate XIT
    public let supportsXIT: Bool

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
        supportsSignalStrength: Bool = true,
        requiresVFOSelection: Bool = true,
        requiresModeFilter: Bool = true,
        powerUnits: PowerUnits = .percentage,
        region: AmateurRadioRegion = .region2,
        supportsRIT: Bool = true,
        supportsXIT: Bool = true
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
        self.requiresVFOSelection = requiresVFOSelection
        self.requiresModeFilter = requiresModeFilter
        self.powerUnits = powerUnits
        self.region = region
        self.supportsRIT = supportsRIT
        self.supportsXIT = supportsXIT
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
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        supportsRIT: true,
        supportsXIT: true
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
        supportsSignalStrength: false,
        requiresVFOSelection: false,
        supportsRIT: false,
        supportsXIT: false
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

    /// Check if a frequency is within an amateur radio band for this radio's region
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: `true` if the frequency is within an amateur band for the configured region
    func isInAmateurBand(_ frequency: UInt64) -> Bool {
        switch region {
        case .region1:
            return Region1AmateurBand.band(for: frequency) != nil
        case .region2:
            return Region2AmateurBand.band(for: frequency) != nil
        case .region3:
            return Region3AmateurBand.band(for: frequency) != nil
        }
    }

    /// Get the amateur band name for a frequency based on this radio's region
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Amateur band name (e.g., "20m", "40m") or `nil` if not in an amateur band
    func amateurBandName(for frequency: UInt64) -> String? {
        switch region {
        case .region1:
            return Region1AmateurBand.band(for: frequency)?.displayName
        case .region2:
            return Region2AmateurBand.band(for: frequency)?.displayName
        case .region3:
            return Region3AmateurBand.band(for: frequency)?.displayName
        }
    }

    /// Check if both the radio supports the frequency AND it's within amateur band allocations
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: `true` if the frequency is both valid for the radio and within amateur bands
    func isValidAmateurFrequency(_ frequency: UInt64) -> Bool {
        return isFrequencyValid(frequency) && isInAmateurBand(frequency)
    }
}
