import Foundation

/// A serial port + baud rate at which a target radio responded to a
/// vendor identify query.
///
/// Returned by ``RadioDiscovery/detect(_:timeoutPerPort:)`` (and the
/// multi-radio overload) so a calling app can show the user which
/// port to use, or pass it straight into a new ``RigController``.
public struct DetectedPort: Sendable, Equatable {
    /// `/dev/cu.*` path where the radio answered.
    public let portPath: String

    /// Baud rate that produced the matching response. Always equal
    /// to the radio's `defaultBaudRate` for now — future revisions
    /// may fall back to additional documented rates.
    public let baudRate: Int

    /// The radio definition that matched on this port. Lets the
    /// multi-radio overload return one entry per detected radio
    /// without losing track of which is which.
    public let radio: RadioDefinition

    /// Raw identify response, ASCII-decoded where applicable
    /// (Kenwood-family text radios) or hex-formatted for Icom
    /// CI-V. Useful for logging and "I'm seeing X, did you expect
    /// Y?" diagnostics.
    public let identityResponse: String

    public init(portPath: String, baudRate: Int, radio: RadioDefinition, identityResponse: String) {
        self.portPath = portPath
        self.baudRate = baudRate
        self.radio = radio
        self.identityResponse = identityResponse
    }

    public static func == (lhs: DetectedPort, rhs: DetectedPort) -> Bool {
        lhs.portPath == rhs.portPath
            && lhs.baudRate == rhs.baudRate
            && lhs.radio.fullName == rhs.radio.fullName
            && lhs.identityResponse == rhs.identityResponse
    }
}

// MARK: - SerialPortEnumerator

/// Lists candidate serial-port paths to probe. The production
/// implementation walks `/dev/cu.*`; tests inject a mock that
/// returns canned paths so detection logic can be exercised
/// without real hardware.
public protocol SerialPortEnumerator: Sendable {
    /// Returns serial-port paths in probe priority order
    /// (most-likely-to-be-a-radio first).
    func availablePorts() -> [String]
}

/// Default ``SerialPortEnumerator`` for macOS. Walks `/dev/`,
/// keeps `cu.*` entries, drops Bluetooth and debug devices, and
/// reorders so common USB-serial adapters (FTDI, Silicon Labs
/// CP210x, CDC-ACM) come first.
public struct DefaultSerialPortEnumerator: SerialPortEnumerator {
    public init() {}

    public func availablePorts() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: "/dev") else {
            return []
        }

        let candidates = entries
            .filter { $0.hasPrefix("cu.") }
            .filter { name in
                // Drop known non-radio serial devices.
                !name.hasPrefix("cu.Bluetooth")
                    && !name.hasPrefix("cu.debug")
                    && !name.hasPrefix("cu.wlan-debug")
                    && !name.hasPrefix("cu.MALS")
            }
            .map { "/dev/" + $0 }

        return candidates.sorted(by: Self.priority)
    }

    /// Ordering predicate. Earlier = higher priority.
    ///
    /// USB-serial adapters with characteristic name fragments
    /// (FTDI's `usbserial`, Silicon Labs CP210x's `SLAB_USBtoUART`,
    /// CDC-ACM `usbmodem`) jump to the front. Everything else
    /// sorts alphabetically.
    static func priority(_ a: String, _ b: String) -> Bool {
        let ra = rank(a)
        let rb = rank(b)
        if ra != rb { return ra < rb }
        return a < b
    }

    private static func rank(_ path: String) -> Int {
        if path.contains("usbserial") { return 0 }    // FTDI-style
        if path.contains("SLAB_USBtoUART") { return 1 } // Silicon Labs CP210x
        if path.contains("usbmodem") { return 2 }     // CDC-ACM
        return 9
    }
}

// MARK: - Probe

/// Outcome of probing one (port, radio) pair. Returned by a
/// ``RadioProbeFunction``; callers can supply their own probe
/// (useful for testing apps without hardware) and report
/// ``RadioProbeOutcome/matched(identityResponse:)`` to confirm a
/// successful identification.
public enum RadioProbeOutcome: Sendable {
    /// The probe identified the requested radio. The identity
    /// response is included for logging.
    case matched(identityResponse: String)
    /// Something answered, but its identity did not match the
    /// requested radio.
    case wrongRadio(identityResponse: String)
    /// Nothing answered within the timeout.
    case noResponse
    /// The probe could not run (port open failed, write error,
    /// unsupported radio family).
    case error
}

/// Async function that probes one (port, radio) pair and returns a
/// ``RadioProbeOutcome``. The production probe opens an
/// ``IOKitSerialPort`` and exchanges identify bytes; tests inject
/// a mock probe to drive ``RadioDiscovery`` without touching real
/// serial ports.
public typealias RadioProbeFunction = @Sendable (_ portPath: String, _ radio: RadioDefinition, _ timeout: TimeInterval) async -> RadioProbeOutcome

// MARK: - RadioDiscovery

/// Auto-detection helper that finds the serial port your radio is
/// plugged into.
///
/// The Hamlib analogue is `rigctl --list` plus a manual choice; this
/// library inverts the workflow — you tell SwiftRigControl which
/// radio you have, and SwiftRigControl probes for it.
///
/// ## Usage
///
/// ```swift
/// // Single radio
/// guard let port = await RadioDiscovery.detect(.Icom.ic7300()) else {
///     print("Couldn't find an IC-7300.")
///     return
/// }
/// let rig = try RigController(
///     radio: .Icom.ic7300(),
///     connection: .serial(path: port.portPath, baudRate: port.baudRate)
/// )
///
/// // Multiple candidate radios (app supports several rigs)
/// let found = await RadioDiscovery.detect([
///     .Icom.ic7300(),
///     .Icom.ic9700(),
///     .Yaesu.ftdx10,
/// ])
/// for hit in found {
///     print("\(hit.radio.fullName) on \(hit.portPath) @ \(hit.baudRate)")
/// }
/// ```
public actor RadioDiscovery {

    private let enumerator: any SerialPortEnumerator
    private let probe: RadioProbeFunction

    /// Build a discovery instance.
    ///
    /// - Parameters:
    ///   - enumerator: Port enumerator. Defaults to
    ///     ``DefaultSerialPortEnumerator``.
    ///   - probe: Probe function. Defaults to the real
    ///     ``IOKitSerialPort``-backed implementation; tests inject
    ///     mocks here.
    public init(
        enumerator: any SerialPortEnumerator = DefaultSerialPortEnumerator(),
        probe: @escaping RadioProbeFunction = RadioDiscovery.defaultProbe
    ) {
        self.enumerator = enumerator
        self.probe = probe
    }

    // MARK: Single-radio detection

    /// Probe the system for one radio. Iterates serial ports in
    /// priority order, identifies the radio at its
    /// ``RadioDefinition/defaultBaudRate``, and returns the first
    /// port that answered correctly.
    ///
    /// - Parameters:
    ///   - radio: The radio definition to look for.
    ///   - timeoutPerPort: Per-port probe timeout. Default 1.5 s.
    /// - Returns: The matching port + baud rate, or `nil` if none
    ///   of the available ports produced a matching identify
    ///   response.
    public static func detect(
        _ radio: RadioDefinition,
        timeoutPerPort: TimeInterval = 1.5
    ) async -> DetectedPort? {
        await RadioDiscovery().detect(radio, timeoutPerPort: timeoutPerPort)
    }

    /// Instance method form. Use this when you constructed the
    /// actor with a custom enumerator or probe (typically tests).
    public func detect(
        _ radio: RadioDefinition,
        timeoutPerPort: TimeInterval = 1.5
    ) async -> DetectedPort? {
        let ports = enumerator.availablePorts()
        for path in ports {
            let result = await probe(path, radio, timeoutPerPort)
            switch result {
            case .matched(let response):
                return DetectedPort(
                    portPath: path,
                    baudRate: radio.defaultBaudRate,
                    radio: radio,
                    identityResponse: response
                )
            case .wrongRadio, .noResponse, .error:
                continue
            }
        }
        return nil
    }

    // MARK: Multi-radio detection

    /// Probe the system for several candidate radios. Each
    /// candidate is matched against the available ports
    /// independently; a single physical radio can therefore match
    /// at most one entry in the returned array.
    ///
    /// Probes are run sequentially in radio order. A port that
    /// already matched a previous radio is skipped (a real serial
    /// port can only be open by one process at a time, and a
    /// physical radio answers only its own identify).
    ///
    /// - Parameters:
    ///   - radios: Candidate radio definitions.
    ///   - timeoutPerPort: Per-port probe timeout. Default 1.5 s.
    /// - Returns: One ``DetectedPort`` per radio that answered;
    ///   empty if none did.
    public static func detect(
        _ radios: [RadioDefinition],
        timeoutPerPort: TimeInterval = 1.5
    ) async -> [DetectedPort] {
        await RadioDiscovery().detect(radios, timeoutPerPort: timeoutPerPort)
    }

    public func detect(
        _ radios: [RadioDefinition],
        timeoutPerPort: TimeInterval = 1.5
    ) async -> [DetectedPort] {
        let ports = enumerator.availablePorts()
        var hits: [DetectedPort] = []
        var consumed: Set<String> = []
        for radio in radios {
            for path in ports where !consumed.contains(path) {
                let result = await probe(path, radio, timeoutPerPort)
                if case .matched(let response) = result {
                    hits.append(DetectedPort(
                        portPath: path,
                        baudRate: radio.defaultBaudRate,
                        radio: radio,
                        identityResponse: response
                    ))
                    consumed.insert(path)
                    break
                }
            }
        }
        return hits
    }

    // MARK: Default probe (real serial I/O)

    /// Default probe that drives a real ``IOKitSerialPort``. Sends
    /// the appropriate vendor identify query, reads a response,
    /// and matches it against the supplied radio definition.
    ///
    /// Replaced via the ``init(enumerator:probe:)`` initializer in
    /// tests so the matching logic can be exercised without
    /// touching `/dev/cu.*`.
    public static let defaultProbe: RadioProbeFunction = { path, radio, timeout in
        let config = SerialConfiguration(path: path, baudRate: radio.defaultBaudRate)
        let port = IOKitSerialPort(configuration: config)

        do {
            try await port.open()
        } catch {
            return .error
        }

        let outcome: RadioProbeOutcome
        do {
            try await port.flush()
            let probe = RadioIdentifyProbe(radio: radio)
            outcome = try await probe.run(transport: port, timeout: timeout)
        } catch {
            outcome = .error
        }
        // Close synchronously before returning so the next probe can
        // open the same (or a related) port without racing against
        // a detached cleanup task. The earlier `defer { Task { ... } }`
        // form raced with subsequent `open()` calls and produced
        // spurious EBUSY errors on Silicon Labs CP210x adapters.
        await port.close()
        return outcome
    }
}
