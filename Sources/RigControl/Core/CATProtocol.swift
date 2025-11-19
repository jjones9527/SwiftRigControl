import Foundation

/// Protocol that all radio CAT (Computer Aided Transceiver) implementations must conform to.
///
/// This protocol defines the standard operations that can be performed on a radio
/// transceiver. Each radio manufacturer's protocol (Icom CI-V, Elecraft, Yaesu, Kenwood)
/// implements this protocol with their specific command formats.
public protocol CATProtocol: Actor {
    /// The serial transport used for communication
    var transport: any SerialTransport { get }

    /// The capabilities of this radio
    var capabilities: RigCapabilities { get }

    /// Initializes a new CAT protocol instance.
    ///
    /// - Parameter transport: The serial transport to use for communication
    init(transport: any SerialTransport)

    /// Connects to the radio and performs any initialization required.
    ///
    /// - Throws: `RigError` if connection fails
    func connect() async throws

    /// Disconnects from the radio.
    func disconnect() async

    // MARK: - Frequency Control

    /// Sets the operating frequency of the specified VFO.
    ///
    /// - Parameters:
    ///   - hz: The desired frequency in Hertz
    ///   - vfo: The VFO to set
    /// - Throws: `RigError` if operation fails
    func setFrequency(_ hz: UInt64, vfo: VFO) async throws

    /// Gets the current operating frequency of the specified VFO.
    ///
    /// - Parameter vfo: The VFO to query
    /// - Returns: The current frequency in Hertz
    /// - Throws: `RigError` if operation fails
    func getFrequency(vfo: VFO) async throws -> UInt64

    // MARK: - Mode Control

    /// Sets the operating mode of the specified VFO.
    ///
    /// - Parameters:
    ///   - mode: The desired operating mode
    ///   - vfo: The VFO to set
    /// - Throws: `RigError` if operation fails
    func setMode(_ mode: Mode, vfo: VFO) async throws

    /// Gets the current operating mode of the specified VFO.
    ///
    /// - Parameter vfo: The VFO to query
    /// - Returns: The current operating mode
    /// - Throws: `RigError` if operation fails
    func getMode(vfo: VFO) async throws -> Mode

    // MARK: - PTT Control

    /// Sets the Push-To-Talk (PTT) state.
    ///
    /// When PTT is enabled (true), the radio will transmit.
    /// When PTT is disabled (false), the radio will receive.
    ///
    /// - Parameter enabled: True to transmit, false to receive
    /// - Throws: `RigError` if operation fails
    func setPTT(_ enabled: Bool) async throws

    /// Gets the current PTT state.
    ///
    /// - Returns: True if transmitting, false if receiving
    /// - Throws: `RigError` if operation fails
    func getPTT() async throws -> Bool

    // MARK: - VFO Control

    /// Selects which VFO is active.
    ///
    /// - Parameter vfo: The VFO to select
    /// - Throws: `RigError` if operation fails
    func selectVFO(_ vfo: VFO) async throws

    // MARK: - Power Control

    /// Sets the RF power level.
    ///
    /// - Parameter watts: Power level in watts (0 to capabilities.maxPower)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support power control
    func setPower(_ watts: Int) async throws

    /// Gets the current RF power level.
    ///
    /// - Returns: Power level in watts
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support power control
    func getPower() async throws -> Int

    // MARK: - Split Operation

    /// Enables or disables split operation.
    ///
    /// In split mode, the radio transmits on one VFO while receiving on another.
    /// Typically, receive on VFO A and transmit on VFO B.
    ///
    /// - Parameter enabled: True to enable split, false to disable
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support split
    func setSplit(_ enabled: Bool) async throws

    /// Gets the current split operation state.
    ///
    /// - Returns: True if split is enabled, false otherwise
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support split
    func getSplit() async throws -> Bool
}

/// Extension providing default implementations for optional operations
extension CATProtocol {
    /// Default implementation throws unsupported error
    public func setPower(_ watts: Int) async throws {
        throw RigError.unsupportedOperation("Power control not supported")
    }

    /// Default implementation throws unsupported error
    public func getPower() async throws -> Int {
        throw RigError.unsupportedOperation("Power control not supported")
    }

    /// Default implementation throws unsupported error
    public func setSplit(_ enabled: Bool) async throws {
        throw RigError.unsupportedOperation("Split operation not supported")
    }

    /// Default implementation throws unsupported error
    public func getSplit() async throws -> Bool {
        throw RigError.unsupportedOperation("Split operation not supported")
    }

    /// Default connect implementation just opens the transport
    public func connect() async throws {
        try await transport.open()
    }

    /// Default disconnect implementation just closes the transport
    public func disconnect() async {
        await transport.close()
    }
}
