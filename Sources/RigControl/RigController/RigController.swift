import Foundation

/// Main controller for amateur radio transceiver operations.
///
/// `RigController` provides a high-level interface for controlling amateur radio
/// transceivers.  It abstracts the underlying protocol details (CI-V, Elecraft,
/// Kenwood CAT, Yaesu CAT) and presents a consistent API across all supported
/// manufacturers and models.
///
/// ## Connection Lifecycle
///
/// Before issuing any command, you **must** call `connect()`.  Attempting to
/// read or set radio state without an active connection throws
/// `RigError.notConnected`.  When you are finished, call `disconnect()` to
/// cleanly close the serial port and release resources.
///
/// ```swift
/// let rig = try RigController(
///     radio: .icomIC9700,
///     connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
/// )
///
/// try await rig.connect()
/// defer { Task { await rig.disconnect() } }
///
/// try await rig.setFrequency(14_230_000, vfo: .a)
/// try await rig.setMode(.usb, vfo: .a)
/// try await rig.setPTT(true)
/// ```
///
/// ## Concurrency Model
///
/// `RigController` is declared as a Swift `actor`, which means:
/// - All stored mutable state is actor-isolated and therefore **thread-safe** by
///   default — no external synchronisation (locks, queues) is required.
/// - Every operation is `async` and is designed for use with Swift structured
///   concurrency (`async`/`await`).  You may call operations concurrently from
///   multiple `Task`s; the actor serialises them automatically.
/// - Do **not** block inside an `await` call on the actor; doing so will stall
///   all other callers until the block returns.
///
/// ## State Cache and Cache Invalidation
///
/// `RigController` maintains an internal `RadioStateCache` to avoid redundant
/// serial-port round-trips.  Cached values have a time-to-live (TTL) of 500 ms
/// by default.  After the TTL expires the next read for that value will query
/// the radio hardware and refresh the cache.
///
/// In the following situations you may want to force a fresh read before the
/// TTL expires:
/// - After the operator physically changes a control on the front panel.
/// - After an external program or network controller modifies the radio state.
/// - During rapid polling loops where stale values are unacceptable.
///
/// Call `invalidateCache()` to immediately discard all cached state, ensuring
/// the next read for every value goes directly to the radio.
///
/// ## Radio-Specific Extensions
///
/// The `protocol` property exposes the underlying `CATProtocol` implementation.
/// Cast it to a manufacturer-specific type to access commands that are outside
/// the standard API:
///
/// ```swift
/// if let icomProto = await rig.protocol as? IcomCIVProtocol {
///     try await icomProto.setAttenuator(6)
/// }
/// ```
///
/// - Warning: Radio-specific commands are not portable.  Always guard the cast
///   and document which radio models the code targets.
public actor RigController {
    /// The radio being controlled
    public let radio: RadioDefinition

    /// The underlying CAT protocol implementation
    internal let proto: any CATProtocol

    /// Whether the controller is currently connected
    internal var connected: Bool = false

    /// State cache for performance optimization
    ///
    /// Caches radio state values to reduce serial port queries and improve responsiveness.
    /// Cache entries expire after a configurable time period (default: 500ms).
    internal let stateCache = RadioStateCache()

    /// Initializes a new rig controller.
    ///
    /// - Parameters:
    ///   - radio: The radio definition (e.g., .icomIC9700)
    ///   - connection: How to connect to the radio
    ///
    /// - Throws: `RigError.unsupportedOperation` if an invalid connection type is specified
    public init(radio: RadioDefinition, connection: ConnectionType) throws {
        self.radio = radio

        // Create the appropriate transport
        let transport: any SerialTransport
        switch connection {
        case .serial(let path, let baudRate):
            let actualBaudRate = baudRate ?? radio.defaultBaudRate
            let config = SerialConfiguration(path: path, baudRate: actualBaudRate)
            transport = IOKitSerialPort(configuration: config)

        case .mock:
            throw RigError.unsupportedOperation(
                "Mock transport is only available in test builds. Use .serial(path:baudRate:) for actual hardware."
            )
        }

        // Create the protocol instance
        self.proto = radio.createProtocol(transport: transport)
    }

    // MARK: - Radio Information

    /// Gets the capabilities of the connected radio.
    public var capabilities: RigCapabilities {
        radio.capabilities
    }

    /// Gets the full name of the radio (manufacturer + model).
    public var radioName: String {
        radio.fullName
    }

    // MARK: - Radio-Specific Protocol Access

    /// Access to the underlying protocol for radio-specific operations.
    ///
    /// This property provides access to the underlying CAT protocol implementation,
    /// allowing access to radio-specific commands that are not part of the standard
    /// RigController API.
    ///
    /// For IC-7600 radios, cast to `IcomCIVProtocol` to access extended commands:
    /// ```swift
    /// if let icomProto = await rig.protocol as? IcomCIVProtocol {
    ///     try await icomProto.setAttenuator(6)
    ///     try await icomProto.setPreamp(1)
    /// }
    /// ```
    ///
    /// - Warning: Radio-specific commands may not be portable across different models.
    ///   Always check the protocol type before casting.
    public var `protocol`: any CATProtocol {
        proto
    }
}
