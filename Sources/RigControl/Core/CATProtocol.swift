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

    // MARK: - Signal Strength

    /// Reads the current signal strength from the radio's S-meter.
    ///
    /// S-meter readings provide real-time signal strength information:
    /// - S0 to S9 represent standard signal levels
    /// - Above S9, readings are expressed as "S9 plus decibels" (e.g., S9+20)
    ///
    /// # Example
    /// ```swift
    /// let signal = try await protocol.getSignalStrength()
    /// print("Signal: \(signal.description)")  // "S7" or "S9+20"
    /// ```
    ///
    /// - Returns: Current signal strength reading
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support S-meter reading
    func getSignalStrength() async throws -> SignalStrength

    // MARK: - RIT/XIT (Receiver/Transmitter Incremental Tuning)

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// RIT allows fine-tuning of the receiver frequency independently from the displayed
    /// VFO frequency. This is useful for:
    /// - Zero-beating CW signals
    /// - Compensating for slight frequency offsets
    /// - Contest and DX operation
    ///
    /// # Example
    /// ```swift
    /// // Enable RIT with +500 Hz offset
    /// try await protocol.setRIT(RITXITState(enabled: true, offset: 500))
    ///
    /// // Disable RIT
    /// try await protocol.setRIT(.disabled)
    /// ```
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support RIT
    func setRIT(_ state: RITXITState) async throws

    /// Gets the current RIT state.
    ///
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support RIT
    func getRIT() async throws -> RITXITState

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// XIT allows fine-tuning of the transmitter frequency independently from the displayed
    /// VFO frequency. This is useful for:
    /// - Split operation in contests
    /// - Working stations on slightly different frequencies
    /// - Compensating for transmit frequency offsets
    ///
    /// # Example
    /// ```swift
    /// // Enable XIT with -1000 Hz offset
    /// try await protocol.setXIT(RITXITState(enabled: true, offset: -1000))
    ///
    /// // Disable XIT
    /// try await protocol.setXIT(.disabled)
    /// ```
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support XIT
    func setXIT(_ state: RITXITState) async throws

    /// Gets the current XIT state.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support XIT
    func getXIT() async throws -> RITXITState

    // MARK: - Memory Channel Operations

    /// Stores a configuration to a memory channel.
    ///
    /// Writes the specified memory channel configuration to the radio's non-volatile memory.
    /// The channel can be recalled later for quick frequency/mode changes.
    ///
    /// - Parameter channel: Memory channel configuration to store
    /// - Throws: `RigError` if operation fails or memory channels not supported
    func setMemoryChannel(_ channel: MemoryChannel) async throws

    /// Reads a memory channel configuration from the radio.
    ///
    /// Retrieves the stored configuration for the specified memory channel number.
    ///
    /// - Parameter number: Memory channel number to read
    /// - Returns: Memory channel configuration
    /// - Throws: `RigError` if operation fails, channel empty, or not supported
    func getMemoryChannel(_ number: Int) async throws -> MemoryChannel

    /// Gets the total number of memory channels supported by the radio.
    ///
    /// Returns the maximum number of user-programmable memory channels.
    /// This may not include special channels (call channels, program scan edges, etc.).
    ///
    /// - Returns: Number of memory channels (e.g., 100, 109, 200)
    /// - Throws: `RigError.unsupportedOperation` if memory not supported
    func getMemoryChannelCount() async throws -> Int

    /// Clears (erases) a memory channel.
    ///
    /// Removes the configuration from the specified memory channel, making it empty.
    ///
    /// - Parameter number: Memory channel number to clear
    /// - Throws: `RigError` if operation fails or not supported
    func clearMemoryChannel(_ number: Int) async throws
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

    /// Default implementation throws unsupported error
    public func getSignalStrength() async throws -> SignalStrength {
        throw RigError.unsupportedOperation("Signal strength reading not supported")
    }

    /// Default implementation throws unsupported error
    public func setRIT(_ state: RITXITState) async throws {
        throw RigError.unsupportedOperation("RIT (Receiver Incremental Tuning) not supported")
    }

    /// Default implementation throws unsupported error
    public func getRIT() async throws -> RITXITState {
        throw RigError.unsupportedOperation("RIT (Receiver Incremental Tuning) not supported")
    }

    /// Default implementation throws unsupported error
    public func setXIT(_ state: RITXITState) async throws {
        throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported")
    }

    /// Default implementation throws unsupported error
    public func getXIT() async throws -> RITXITState {
        throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported")
    }

    /// Default implementation throws unsupported error
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        throw RigError.unsupportedOperation("Memory channel operations not supported")
    }

    /// Default implementation throws unsupported error
    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        throw RigError.unsupportedOperation("Memory channel operations not supported")
    }

    /// Default implementation throws unsupported error
    public func getMemoryChannelCount() async throws -> Int {
        throw RigError.unsupportedOperation("Memory channel operations not supported")
    }

    /// Default implementation throws unsupported error
    public func clearMemoryChannel(_ number: Int) async throws {
        throw RigError.unsupportedOperation("Memory channel operations not supported")
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
