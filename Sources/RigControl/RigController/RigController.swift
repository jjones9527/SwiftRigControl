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
///     radio: .icomIC9700(),
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
/// The ``vendorExtensions`` property returns a typed ``VendorExtensions``
/// enum carrying the concrete protocol actor for the radio's vendor.
/// Pattern-match to reach vendor-specific commands without a stringly-
/// typed cast:
///
/// ```swift
/// if case .icom(let icom) = await rig.vendorExtensions {
///     try await icom.setAttenuator(6)
/// }
/// ```
///
/// For unusual cases the typed enum doesn't cover (hardware validators,
/// custom test fixtures), use the ``rawProtocol`` escape hatch — but
/// be aware that anything reached through it is unversioned and may
/// change between releases.
///
/// - Warning: Vendor-specific commands are not portable across
///   manufacturers. Document which radio models your code targets.
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

    /// Active subscribers to the ``events`` stream. Keyed by UUID so
    /// individual subscribers can deregister on cancellation without
    /// scanning the collection.
    internal var eventSubscribers: [UUID: AsyncStream<RigStateEvent>.Continuation] = [:]

    /// Most recent connection state. Replayed to new subscribers so
    /// SwiftUI views that subscribe after `connect()` still see the
    /// right initial value.
    internal var connectionState: ConnectionState = .disconnected

    /// Active per-field polling tasks (Phase 2.2). Keyed by field
    /// name so individual fields can be retuned without restarting
    /// the entire poller. Empty when polling is stopped.
    internal var pollingTasks: [String: Task<Void, Never>] = [:]

    /// Active connection-health monitor task (Phase 2.3). `nil`
    /// when the monitor is stopped.
    internal var healthMonitorTask: Task<Void, Never>?

    /// Initializes a new rig controller.
    ///
    /// - Parameters:
    ///   - radio: The radio definition (e.g., .icomIC9700)
    ///   - connection: How to connect to the radio
    ///
    /// - Throws: `RigError.unsupportedOperation` if an invalid connection type is specified
    public init(radio: RadioDefinition, connection: ConnectionType) throws {
        self.radio = radio

        // Create the appropriate transport. For .mock, we hand the
        // radio's protocolFactory a MockSerialTransport — for a dummy
        // radio that transport is a no-op (DummyCATProtocol ignores
        // it), and for a real radio it lets you script byte-level
        // responses for protocol testing.
        let transport: any SerialTransport
        switch connection {
        case .serial(let path, let baudRate):
            let actualBaudRate = baudRate ?? radio.defaultBaudRate
            let config = SerialConfiguration(path: path, baudRate: actualBaudRate)
            transport = IOKitSerialPort(configuration: config)

        case .mock:
            transport = MockSerialTransport()
        }

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

    /// How thoroughly this radio has been validated against real hardware.
    ///
    /// SwiftRigControl ships definitions for many more radios than the
    /// maintainers own. Use this to tell users whether the radio they
    /// selected has been exercised against real hardware
    /// (``RadioDefinition/VerificationStatus/hardware``) or is
    /// definition-only (``RadioDefinition/VerificationStatus/definition``).
    public var verificationStatus: RadioDefinition.VerificationStatus {
        radio.verificationStatus
    }

    // MARK: - Radio-Specific Protocol Access

    /// Direct, type-erased access to the underlying CAT protocol
    /// actor. Use this as an explicit escape hatch when the
    /// typed ``vendorExtensions`` enum doesn't cover what you need.
    ///
    /// **Prefer ``vendorExtensions`` for most cases.** That returns
    /// a discriminated ``VendorExtensions`` enum carrying the
    /// concrete protocol actor for the radio's vendor — no
    /// stringly-typed `as?` cast required, and the compiler tells
    /// you when a new vendor case appears that your code hasn't
    /// handled.
    ///
    /// ## When to use `rawProtocol`
    ///
    /// - **Hardware validators** that touch every per-model method
    ///   (the `Tools/SwiftRigControlTools/` validators use it).
    /// - **Custom simulators or test fixtures** that need to reach
    ///   methods not exposed by any vendor extension.
    /// - **Debugging or one-off scripts** where the typed surface
    ///   is overkill.
    ///
    /// Anything reached through `rawProtocol` is unversioned — the
    /// surface may change between SwiftRigControl releases without
    /// a deprecation cycle. If you find yourself touching it from
    /// app code, consider opening an issue: it may belong on a
    /// trait protocol or as a curated vendor extension.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Almost always prefer:
    /// if case .icom(let icom) = await rig.vendorExtensions {
    ///     try await icom.setAttenuatorIC9700(.dB12)
    /// }
    ///
    /// // Escape hatch:
    /// let raw = await rig.rawProtocol
    /// // ... type-erased access, e.g. for a custom test fixture
    /// ```
    public var rawProtocol: any CATProtocol {
        proto
    }
}
