import Foundation

/// Universal CAT (Computer Aided Transceiver) operations that every
/// supported radio implements.
///
/// `CATProtocol` is intentionally narrow — only operations every
/// real amateur transceiver supports live here (frequency, mode,
/// PTT, VFO selection). Optional radio features (power, split,
/// RIT/XIT, DSP, levels, memory, TX meters, CW keyer, scanning,
/// antenna) are declared as **capability trait protocols** in
/// `CATProtocolTraits.swift` — see ``SupportsPower``,
/// ``SupportsSplit``, ``SupportsAGC``, ``SupportsTXMeters``, etc.
///
/// ## Rationale for the trait split
///
/// Earlier versions of this protocol carried ~40 methods with
/// default `throw .unsupportedOperation` extensions. That made
/// the protocol fat and let conformers silently "support"
/// features they didn't actually implement (by inheriting the
/// throwing default). Splitting capabilities into focused traits
/// means:
///
/// - Each concrete protocol's conformance list is the contract:
///   `IcomCIVProtocol: CATProtocol, SupportsPower, SupportsSplit, …`
///   tells the reader (and the compiler) exactly what it supports.
/// - Adding a new feature later doesn't force every existing
///   conformer to implement another method.
/// - Third-party conformers (custom radios, simulators) get the
///   same compiler check.
///
/// `RigController` dispatches each call via `as? any SupportsX`,
/// throwing ``RigError/unsupportedOperation(_:)`` with the same
/// error message the old defaults produced — so app code that
/// calls `rig.setAGC(.fast)` sees identical behavior across the
/// refactor boundary.
public protocol CATProtocol: Actor {
    /// The serial transport used for communication.
    var transport: any SerialTransport { get }

    /// The capabilities of this radio.
    var capabilities: RigCapabilities { get }

    /// Connects to the radio and performs any initialization required.
    ///
    /// - Throws: ``RigError`` if connection fails.
    func connect() async throws

    /// Disconnects from the radio.
    func disconnect() async

    // MARK: - Frequency Control

    /// Sets the operating frequency of the specified VFO.
    ///
    /// - Parameters:
    ///   - hz: The desired frequency in Hertz.
    ///   - vfo: The VFO to set.
    /// - Throws: ``RigError`` if operation fails.
    func setFrequency(_ hz: UInt64, vfo: VFO) async throws

    /// Gets the current operating frequency of the specified VFO.
    ///
    /// - Parameter vfo: The VFO to query.
    /// - Returns: The current frequency in Hertz.
    /// - Throws: ``RigError`` if operation fails.
    func getFrequency(vfo: VFO) async throws -> UInt64

    // MARK: - Mode Control

    /// Sets the operating mode of the specified VFO.
    ///
    /// - Parameters:
    ///   - mode: The desired operating mode.
    ///   - vfo: The VFO to set.
    /// - Throws: ``RigError`` if operation fails.
    func setMode(_ mode: Mode, vfo: VFO) async throws

    /// Gets the current operating mode of the specified VFO.
    ///
    /// - Parameter vfo: The VFO to query.
    /// - Returns: The current operating mode.
    /// - Throws: ``RigError`` if operation fails.
    func getMode(vfo: VFO) async throws -> Mode

    // MARK: - PTT Control

    /// Sets the Push-To-Talk (PTT) state.
    ///
    /// When PTT is enabled, the radio transmits; when disabled,
    /// it receives.
    ///
    /// - Parameter enabled: `true` to transmit, `false` to receive.
    /// - Throws: ``RigError`` if operation fails.
    func setPTT(_ enabled: Bool) async throws

    /// Gets the current PTT state.
    ///
    /// - Returns: `true` if transmitting, `false` if receiving.
    /// - Throws: ``RigError`` if operation fails.
    func getPTT() async throws -> Bool

    // MARK: - VFO Control

    /// Selects which VFO is active.
    ///
    /// - Parameter vfo: The VFO to select.
    /// - Throws: ``RigError`` if operation fails.
    func selectVFO(_ vfo: VFO) async throws
}

// MARK: - Default lifecycle implementation

extension CATProtocol {
    /// Default connect implementation just opens the transport.
    public func connect() async throws {
        try await transport.open()
    }

    /// Default disconnect implementation just closes the transport.
    public func disconnect() async {
        await transport.close()
    }
}
