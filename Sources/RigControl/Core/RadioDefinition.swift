import Foundation

/// Represents a specific radio model with its protocol and capabilities.
public struct RadioDefinition: Sendable {
    /// Radio manufacturer
    public let manufacturer: Manufacturer

    /// Radio model name
    public let model: String

    /// Default baud rate for this radio
    public let defaultBaudRate: Int

    /// Radio capabilities
    public let capabilities: RigCapabilities

    /// CI-V address (for Icom radios)
    public let civAddress: UInt8?

    /// How thoroughly this radio definition has been validated.
    ///
    /// See ``VerificationStatus`` for the meaning of each value. A
    /// ``VerificationStatus/definition`` radio may work — but no one
    /// from the SwiftRigControl project has verified it against the
    /// real hardware.
    public let verificationStatus: VerificationStatus

    /// Protocol factory closure
    private let protocolFactory: @Sendable (any SerialTransport) -> any CATProtocol

    /// The manufacturer of a radio. The raw value is a
    /// human-readable name suitable for display in UI.
    public enum Manufacturer: String, Sendable {
        case icom = "Icom"
        case elecraft = "Elecraft"
        case yaesu = "Yaesu"
        case kenwood = "Kenwood"
        case xiegu = "Xiegu"
        case tentec = "Ten-Tec"

        /// Generic in-memory dummy radio (no real manufacturer). Used
        /// by `RadioDefinition.dummy(...)` for previews, demo apps,
        /// and tutorials. The Swift analogue of Hamlib's Model 1.
        case dummy = "Dummy"
    }

    /// Indicates how thoroughly a radio definition has been validated.
    ///
    /// SwiftRigControl ships definitions for many more radios than the
    /// maintainers own. This field lets callers (and the UI of apps
    /// built on top) tell users whether a given radio has actually been
    /// exercised against real hardware, or whether it is paper-only.
    public enum VerificationStatus: String, Sendable, CaseIterable {
        /// Exercised against the real radio via the matching validator
        /// in `HardwareValidation/`. Frequency, mode, PTT, and at least
        /// one read-back operation are confirmed working.
        case hardware

        /// Protocol, capabilities, and command set are implemented —
        /// typically cross-referenced against the manufacturer manual
        /// and Hamlib source — but no real-hardware verification has
        /// been performed. May work; not proven.
        case definition

        /// Human-readable label suitable for UI display.
        public var displayName: String {
            switch self {
            case .hardware:   return "Hardware verified"
            case .definition: return "Definition only"
            }
        }
    }

    /// Initializes a new radio definition.
    ///
    /// - Parameters:
    ///   - manufacturer: Radio manufacturer (Icom, Yaesu, etc.).
    ///   - model: Radio model name (e.g. "IC-7600").
    ///   - defaultBaudRate: Default CAT baud rate for this radio.
    ///   - capabilities: Radio capability flags and limits.
    ///   - civAddress: CI-V bus address for Icom radios; `nil` otherwise.
    ///   - verificationStatus: How thoroughly this definition has been
    ///     validated. Defaults to ``VerificationStatus/definition``.
    ///     Set to ``VerificationStatus/hardware`` only for radios that
    ///     have been exercised against the real hardware via a
    ///     `HardwareValidation/` validator.
    ///   - protocolFactory: Closure that builds a `CATProtocol`
    ///     conformer over a given transport.
    public init(
        manufacturer: Manufacturer,
        model: String,
        defaultBaudRate: Int,
        capabilities: RigCapabilities,
        civAddress: UInt8? = nil,
        verificationStatus: VerificationStatus = .definition,
        protocolFactory: @escaping @Sendable (any SerialTransport) -> any CATProtocol
    ) {
        self.manufacturer = manufacturer
        self.model = model
        self.defaultBaudRate = defaultBaudRate
        self.capabilities = capabilities
        self.civAddress = civAddress
        self.verificationStatus = verificationStatus
        self.protocolFactory = protocolFactory
    }

    /// Creates a protocol instance for this radio.
    public func createProtocol(transport: any SerialTransport) -> any CATProtocol {
        protocolFactory(transport)
    }

    /// Full radio name (manufacturer + model)
    public var fullName: String {
        "\(manufacturer.rawValue) \(model)"
    }
}

// MARK: - Connection Type

/// Represents different ways to connect to a radio.
public enum ConnectionType {
    /// Serial port connection over a `/dev/cu.*` device.
    case serial(path: String, baudRate: Int? = nil)

    /// In-memory transport with no real I/O.
    ///
    /// Pair with `RadioDefinition.dummy(...)` for SwiftUI previews,
    /// demo apps, and tutorials — the controller behaves like a real
    /// radio you can `setFrequency` / `setMode` / `setPTT` against,
    /// but never touches a serial port.
    ///
    /// Pair with a real radio definition (e.g. `.icomIC7600()`) for
    /// protocol-level testing: the radio's `CATProtocol` actually
    /// runs and produces byte sequences you can inspect through the
    /// underlying ``MockSerialTransport``.
    case mock
}
