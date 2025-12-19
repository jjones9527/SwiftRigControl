import Foundation

/// Represents a memory channel configuration for radio transceivers.
///
/// Memory channels allow storing frequency, mode, and other settings for quick recall.
/// This model provides a unified interface across all radio manufacturers while allowing
/// for manufacturer-specific features through optional properties.
///
/// ## Usage
///
/// ```swift
/// // Create a basic memory channel
/// let channel = MemoryChannel(
///     number: 1,
///     frequency: 14_230_000,  // 14.230 MHz
///     mode: .usb,
///     name: "20m Net"
/// )
///
/// // Store to radio
/// try await rig.setMemoryChannel(channel)
///
/// // Recall from radio
/// let stored = try await rig.getMemoryChannel(1)
/// print("Channel \(stored.number): \(stored.name ?? "Unnamed")")
/// print("Frequency: \(stored.frequency) Hz, Mode: \(stored.mode)")
/// ```
///
/// ## Manufacturer-Specific Features
///
/// Different manufacturers support different memory channel features:
/// - **Icom**: Supports split, data mode, filter selection, duplex offset
/// - **Yaesu**: Supports CTCSS/DCS tones, skip settings, power levels
/// - **Kenwood**: Supports tone squelch, lockout, reverse
/// - **Elecraft**: Supports extended settings via menu commands
///
/// Use optional properties for features that may not be supported by all radios.
public struct MemoryChannel: Sendable, Equatable, Codable {
    // MARK: - Core Properties (Universal)

    /// Memory channel number
    ///
    /// Valid range depends on radio model:
    /// - IC-7600: 0-99
    /// - IC-7100: 1-109 (includes program scan edges and call channels)
    /// - IC-9700: 1-109 (per-band, includes special channels)
    /// - Yaesu: Typically 1-99 or 1-117
    /// - Kenwood: Typically 0-99 or 0-299
    public let number: Int

    /// Operating frequency in Hertz
    public let frequency: UInt64

    /// Operating mode (LSB, USB, CW, FM, etc.)
    public let mode: Mode

    /// Optional channel name/label
    ///
    /// Maximum length varies by manufacturer:
    /// - Icom: 10 characters
    /// - Yaesu: 8-16 characters depending on model
    /// - Kenwood: 8 characters
    public let name: String?

    // MARK: - Optional Features (Manufacturer-Dependent)

    /// Split operation enabled
    ///
    /// When true, transmit frequency differs from receive frequency.
    /// Use `txFrequency` to specify the transmit frequency.
    public let splitEnabled: Bool?

    /// Transmit frequency when split is enabled (in Hertz)
    ///
    /// Only used when `splitEnabled` is true.
    public let txFrequency: UInt64?

    /// CTCSS tone frequency in Hz
    ///
    /// Common values: 67.0, 77.0, 88.5, 100.0, 114.8, 123.0, 127.3, 136.5, 146.2, 156.7, 167.9, 179.9, 192.8, 203.5, 206.5, 218.1, 225.7, 229.1, 241.8, 250.3, 254.1 Hz
    ///
    /// Used primarily on VHF/UHF FM channels for repeater access.
    public let toneFrequency: Double?

    /// CTCSS tone squelch frequency in Hz
    ///
    /// Receiver only opens squelch when this tone is detected.
    public let toneSqelchFrequency: Double?

    /// DCS (Digital Coded Squelch) code
    ///
    /// Valid range: 023-754 (octal)
    /// Used as an alternative to CTCSS on some systems.
    public let dcsCode: Int?

    /// Duplex offset in Hz
    ///
    /// Positive for + duplex (TX higher than RX)
    /// Negative for - duplex (TX lower than RX)
    /// Zero or nil for simplex
    ///
    /// Common repeater offsets:
    /// - 2m: ±600 kHz
    /// - 70cm: ±5 MHz
    /// - 6m: ±1 MHz
    public let duplexOffset: Int?

    /// Skip this channel during scanning
    ///
    /// When true, memory scanner will skip this channel.
    public let skipScan: Bool?

    /// Channel is locked out (cannot be accidentally overwritten)
    public let lockout: Bool?

    /// Filter bandwidth selection
    ///
    /// Interpretation varies by manufacturer:
    /// - Icom: 1=Wide, 2=Mid, 3=Narrow
    /// - Yaesu: Filter number 1-3
    /// - Kenwood: IF filter selection
    public let filterSelection: Int?

    /// Data mode enabled (for digital modes)
    ///
    /// Enables data sub-mode on compatible radios.
    /// For example, USB-D on Icom radios.
    public let dataMode: Bool?

    /// Transmit power level (radio-specific scale)
    ///
    /// - Icom: 0-255 (percentage)
    /// - Yaesu: 5-100 (watts or percentage)
    /// - Kenwood: 5-100 (watts)
    public let powerLevel: Int?

    // MARK: - Initialization

    /// Creates a new memory channel configuration.
    ///
    /// - Parameters:
    ///   - number: Memory channel number
    ///   - frequency: Operating frequency in Hz
    ///   - mode: Operating mode
    ///   - name: Optional channel name (max length varies by radio)
    ///   - splitEnabled: Split operation enabled (default: nil)
    ///   - txFrequency: Transmit frequency when split (default: nil)
    ///   - toneFrequency: CTCSS tone in Hz (default: nil)
    ///   - toneSqelchFrequency: CTCSS tone squelch in Hz (default: nil)
    ///   - dcsCode: DCS code (default: nil)
    ///   - duplexOffset: Duplex offset in Hz (default: nil)
    ///   - skipScan: Skip during scan (default: nil)
    ///   - lockout: Channel locked (default: nil)
    ///   - filterSelection: Filter selection (default: nil)
    ///   - dataMode: Data mode enabled (default: nil)
    ///   - powerLevel: TX power level (default: nil)
    public init(
        number: Int,
        frequency: UInt64,
        mode: Mode,
        name: String? = nil,
        splitEnabled: Bool? = nil,
        txFrequency: UInt64? = nil,
        toneFrequency: Double? = nil,
        toneSqelchFrequency: Double? = nil,
        dcsCode: Int? = nil,
        duplexOffset: Int? = nil,
        skipScan: Bool? = nil,
        lockout: Bool? = nil,
        filterSelection: Int? = nil,
        dataMode: Bool? = nil,
        powerLevel: Int? = nil
    ) {
        self.number = number
        self.frequency = frequency
        self.mode = mode
        self.name = name
        self.splitEnabled = splitEnabled
        self.txFrequency = txFrequency
        self.toneFrequency = toneFrequency
        self.toneSqelchFrequency = toneSqelchFrequency
        self.dcsCode = dcsCode
        self.duplexOffset = duplexOffset
        self.skipScan = skipScan
        self.lockout = lockout
        self.filterSelection = filterSelection
        self.dataMode = dataMode
        self.powerLevel = powerLevel
    }

    // MARK: - Convenience Properties

    /// Whether this channel is configured for simplex operation
    public var isSimplex: Bool {
        duplexOffset == nil || duplexOffset == 0
    }

    /// Whether this channel has any tone configured (CTCSS or DCS)
    public var hasTone: Bool {
        toneFrequency != nil || toneSqelchFrequency != nil || dcsCode != nil
    }

    /// Human-readable description of the channel
    public var description: String {
        var desc = "Ch \(number)"
        if let name = name, !name.isEmpty {
            desc += " (\(name))"
        }
        desc += ": \(Double(frequency) / 1_000_000) MHz \(mode)"

        if let split = splitEnabled, split, let txFreq = txFrequency {
            desc += " [Split TX: \(Double(txFreq) / 1_000_000) MHz]"
        }

        return desc
    }
}

// MARK: - CustomStringConvertible

extension MemoryChannel: CustomStringConvertible {}

// MARK: - Memory Channel Validation

public extension MemoryChannel {
    /// Validates the memory channel configuration for a specific radio.
    ///
    /// - Parameter capabilities: Radio capabilities to validate against
    /// - Throws: `RigError` if configuration is invalid for the radio
    func validate(for capabilities: RigCapabilities) throws {
        // Validate frequency range
        guard capabilities.isFrequencyValid(frequency) else {
            throw RigError.frequencyOutOfRange(frequency, model: "")
        }

        // Validate mode is supported
        guard capabilities.supportedModes.contains(mode) else {
            throw RigError.modeNotSupported(mode, frequency: frequency)
        }

        // Validate split configuration
        if let split = splitEnabled, split {
            guard capabilities.hasSplit else {
                throw RigError.unsupportedOperation("Split operation not supported")
            }

            if let txFreq = txFrequency {
                guard capabilities.isFrequencyValid(txFreq) else {
                    throw RigError.frequencyOutOfRange(txFreq, model: "")
                }
            }
        }

        // Validate tone frequency is in standard CTCSS range
        if let tone = toneFrequency {
            guard tone >= 67.0 && tone <= 254.1 else {
                throw RigError.invalidParameter("CTCSS tone must be 67.0-254.1 Hz")
            }
        }

        // Validate DCS code is valid octal
        if let dcs = dcsCode {
            guard dcs >= 23 && dcs <= 754 else {
                throw RigError.invalidParameter("DCS code must be 023-754 (octal)")
            }
        }
    }
}
