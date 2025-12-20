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

    /// Protocol factory closure
    private let protocolFactory: @Sendable (any SerialTransport) -> any CATProtocol

    public enum Manufacturer: String, Sendable {
        case icom = "Icom"
        case elecraft = "Elecraft"
        case yaesu = "Yaesu"
        case kenwood = "Kenwood"
        case xiegu = "Xiegu"
        case tentec = "Ten-Tec"
    }

    /// Initializes a new radio definition.
    public init(
        manufacturer: Manufacturer,
        model: String,
        defaultBaudRate: Int,
        capabilities: RigCapabilities,
        civAddress: UInt8? = nil,
        protocolFactory: @escaping @Sendable (any SerialTransport) -> any CATProtocol
    ) {
        self.manufacturer = manufacturer
        self.model = model
        self.defaultBaudRate = defaultBaudRate
        self.capabilities = capabilities
        self.civAddress = civAddress
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
    /// Serial port connection
    case serial(path: String, baudRate: Int? = nil)

    /// Mock connection for testing
    case mock
}
