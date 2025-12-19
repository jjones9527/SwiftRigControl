import Foundation

/// Main controller for amateur radio transceiver operations.
///
/// RigController provides a high-level interface for controlling amateur radio transceivers.
/// It abstracts the underlying protocol details and provides a consistent API across different
/// radio manufacturers and models.
///
/// Example usage:
/// ```swift
/// let rig = RigController(
///     radio: .icomIC9700,
///     connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
/// )
///
/// try await rig.connect()
/// try await rig.setFrequency(14_230_000, vfo: .a)
/// try await rig.setMode(.usb, vfo: .a)
/// try await rig.setPTT(true)
/// ```
public actor RigController {
    /// The radio being controlled
    public let radio: RadioDefinition

    /// The underlying CAT protocol implementation
    private let proto: any CATProtocol

    /// Whether the controller is currently connected
    private var connected: Bool = false

    /// State cache for performance optimization
    ///
    /// Caches radio state values to reduce serial port queries and improve responsiveness.
    /// Cache entries expire after a configurable time period (default: 500ms).
    private let stateCache = RadioStateCache()

    /// Initializes a new rig controller.
    ///
    /// - Parameters:
    ///   - radio: The radio definition (e.g., .icomIC9700)
    ///   - connection: How to connect to the radio
    public init(radio: RadioDefinition, connection: ConnectionType) {
        self.radio = radio

        // Create the appropriate transport
        let transport: any SerialTransport
        switch connection {
        case .serial(let path, let baudRate):
            let actualBaudRate = baudRate ?? radio.defaultBaudRate
            let config = SerialConfiguration(path: path, baudRate: actualBaudRate)
            transport = IOKitSerialPort(configuration: config)

        case .mock:
            // For testing - would need a mock transport implementation
            fatalError("Mock transport not yet implemented")
        }

        // Create the protocol instance
        self.proto = radio.createProtocol(transport: transport)
    }

    // MARK: - Connection Management

    /// Connects to the radio.
    ///
    /// This opens the serial port connection and performs any necessary initialization.
    ///
    /// - Throws: `RigError` if connection fails
    public func connect() async throws {
        guard !connected else { return }
        try await proto.connect()
        connected = true
    }

    /// Disconnects from the radio.
    public func disconnect() async {
        guard connected else { return }
        await proto.disconnect()
        connected = false
        // Invalidate cache on disconnect
        await stateCache.invalidate()
    }

    /// Checks if the controller is connected.
    public var isConnected: Bool {
        connected
    }

    // MARK: - Frequency Control

    /// Sets the operating frequency of the specified VFO.
    ///
    /// - Parameters:
    ///   - hz: The desired frequency in Hertz (e.g., 14230000 for 14.230 MHz)
    ///   - vfo: The VFO to set (defaults to VFO A)
    ///
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.commandFailed` if radio rejects the frequency
    ///   - `RigError.timeout` if radio doesn't respond
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setFrequency(14_230_000, vfo: .a)  // 20m SSTV calling frequency
    /// ```
    public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setFrequency(hz, vfo: vfo)
        // Invalidate cached frequency for this VFO
        await stateCache.invalidate("freq_\(vfo)")
    }

    /// Gets the current operating frequency of the specified VFO.
    ///
    /// - Parameters:
    ///   - vfo: The VFO to query (defaults to VFO A)
    ///   - cached: Whether to use cached value if available (defaults to true)
    /// - Returns: The current frequency in Hertz
    /// - Throws: `RigError` if operation fails
    ///
    /// # Caching
    /// When `cached` is true, the controller returns a cached frequency if available
    /// and less than 500ms old. This significantly improves performance for frequent
    /// queries (10-20x faster). Set `cached` to false to force a fresh query.
    ///
    /// - Example:
    /// ```swift
    /// // Fast cached read
    /// let freq = try await rig.frequency(cached: true)
    ///
    /// // Force fresh query
    /// let freshFreq = try await rig.frequency(cached: false)
    /// ```
    public func frequency(vfo: VFO = .a, cached: Bool = true) async throws -> UInt64 {
        guard connected else {
            throw RigError.notConnected
        }

        if cached {
            return try await stateCache.get("freq_\(vfo)", maxAge: 0.5) {
                try await proto.getFrequency(vfo: vfo)
            }
        } else {
            await stateCache.invalidate("freq_\(vfo)")
            return try await proto.getFrequency(vfo: vfo)
        }
    }

    // MARK: - Mode Control

    /// Sets the operating mode of the specified VFO.
    ///
    /// - Parameters:
    ///   - mode: The desired operating mode
    ///   - vfo: The VFO to set (defaults to VFO A)
    ///
    /// - Throws: `RigError` if operation fails
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setMode(.usb, vfo: .a)  // USB for SSTV on 20m
    /// ```
    public func setMode(_ mode: Mode, vfo: VFO = .a) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setMode(mode, vfo: vfo)
        // Invalidate cached mode for this VFO
        await stateCache.invalidate("mode_\(vfo)")
    }

    /// Gets the current operating mode of the specified VFO.
    ///
    /// - Parameters:
    ///   - vfo: The VFO to query (defaults to VFO A)
    ///   - cached: Whether to use cached value if available (defaults to true)
    /// - Returns: The current operating mode
    /// - Throws: `RigError` if operation fails
    ///
    /// # Caching
    /// When `cached` is true, returns cached mode if available and recent.
    /// Set `cached` to false to force a fresh query.
    public func mode(vfo: VFO = .a, cached: Bool = true) async throws -> Mode {
        guard connected else {
            throw RigError.notConnected
        }

        if cached {
            return try await stateCache.get("mode_\(vfo)", maxAge: 0.5) {
                try await proto.getMode(vfo: vfo)
            }
        } else {
            await stateCache.invalidate("mode_\(vfo)")
            return try await proto.getMode(vfo: vfo)
        }
    }

    // MARK: - PTT Control

    /// Sets the Push-To-Talk (PTT) state.
    ///
    /// When PTT is enabled, the radio will transmit. When disabled, it will receive.
    ///
    /// - Parameter enabled: True to transmit, false to receive
    /// - Throws: `RigError` if operation fails
    ///
    /// - Important: Always disable PTT when finished transmitting to avoid
    ///   accidentally transmitting when not intended.
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setPTT(true)   // Start transmitting
    /// // ... transmit audio ...
    /// try await rig.setPTT(false)  // Stop transmitting
    /// ```
    public func setPTT(_ enabled: Bool) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setPTT(enabled)
    }

    /// Gets the current PTT state.
    ///
    /// - Returns: True if transmitting, false if receiving
    /// - Throws: `RigError` if operation fails
    public func isPTTEnabled() async throws -> Bool {
        guard connected else {
            throw RigError.notConnected
        }
        return try await proto.getPTT()
    }

    // MARK: - VFO Control

    /// Selects which VFO is active.
    ///
    /// - Parameter vfo: The VFO to select
    /// - Throws: `RigError` if operation fails
    public func selectVFO(_ vfo: VFO) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.selectVFO(vfo)
    }

    // MARK: - Power Control

    /// Sets the RF power level.
    ///
    /// - Parameter watts: Power level in watts (0 to radio's maximum power)
    /// - Throws:
    ///   - `RigError.unsupportedOperation` if radio doesn't support power control
    ///   - `RigError.invalidParameter` if watts exceeds radio's maximum
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setPower(50)  // Set to 50 watts
    /// ```
    public func setPower(_ watts: Int) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard radio.capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported by \(radio.fullName)")
        }

        guard watts >= 0 && watts <= radio.capabilities.maxPower else {
            throw RigError.invalidParameter(
                "Power must be between 0 and \(radio.capabilities.maxPower) watts"
            )
        }

        try await proto.setPower(watts)
    }

    /// Gets the current RF power level.
    ///
    /// - Returns: Power level in watts
    /// - Throws: `RigError` if operation fails
    public func power() async throws -> Int {
        guard connected else {
            throw RigError.notConnected
        }
        return try await proto.getPower()
    }

    // MARK: - Split Operation

    /// Enables or disables split operation.
    ///
    /// In split mode, the radio transmits on one VFO while receiving on another.
    /// This is commonly used for working DX stations that are listening on a different
    /// frequency than they're transmitting on.
    ///
    /// - Parameter enabled: True to enable split, false to disable
    /// - Throws:
    ///   - `RigError.unsupportedOperation` if radio doesn't support split
    ///   - `RigError.notConnected` if not connected
    ///
    /// - Example:
    /// ```swift
    /// // Set up for split operation
    /// try await rig.setFrequency(14_195_000, vfo: .a)  // Receive frequency
    /// try await rig.setFrequency(14_225_000, vfo: .b)  // Transmit frequency
    /// try await rig.setSplit(true)                      // Enable split
    /// // Radio now receives on VFO A, transmits on VFO B
    /// ```
    public func setSplit(_ enabled: Bool) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard radio.capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported by \(radio.fullName)")
        }

        try await proto.setSplit(enabled)
    }

    /// Gets the current split operation state.
    ///
    /// - Returns: True if split is enabled, false otherwise
    /// - Throws: `RigError` if operation fails
    public func isSplitEnabled() async throws -> Bool {
        guard connected else {
            throw RigError.notConnected
        }
        return try await proto.getSplit()
    }

    // MARK: - Signal Strength

    /// Reads the current signal strength from the radio's S-meter.
    ///
    /// S-meter readings provide real-time signal strength information:
    /// - S0 to S9 represent standard signal levels
    /// - Above S9, readings are expressed as "S9 plus decibels" (e.g., S9+20)
    ///
    /// - Parameters:
    ///   - cached: Whether to use cached value if available (defaults to true)
    /// - Returns: Current signal strength
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if radio doesn't support S-meter reading
    ///
    /// # Caching
    /// Signal strength readings are cached for 500ms by default to allow for
    /// rapid UI updates without overloading the serial port. Set `cached` to false
    /// for the most recent reading.
    ///
    /// # Example
    /// ```swift
    /// let signal = try await rig.signalStrength()
    /// print("Signal: \(signal.description)")  // "S7" or "S9+20"
    ///
    /// if signal.isStrongSignal {
    ///     print("Strong signal detected!")
    /// }
    /// ```
    public func signalStrength(cached: Bool = true) async throws -> SignalStrength {
        guard connected else {
            throw RigError.notConnected
        }

        if cached {
            return try await stateCache.get("signal_strength", maxAge: 0.5) {
                try await proto.getSignalStrength()
            }
        } else {
            await stateCache.invalidate("signal_strength")
            return try await proto.getSignalStrength()
        }
    }

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// RIT allows fine-tuning of the receiver frequency independently from the displayed
    /// VFO frequency. This is useful for:
    /// - Zero-beating CW signals
    /// - Compensating for slight frequency offsets
    /// - Contest and DX operation
    ///
    /// Most radios support offsets between -9999 Hz and +9999 Hz.
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support RIT
    ///
    /// # Example
    /// ```swift
    /// // Enable RIT with +500 Hz offset
    /// try await rig.setRIT(RITXITState(enabled: true, offset: 500))
    ///
    /// // Disable RIT
    /// try await rig.setRIT(.disabled)
    ///
    /// // Adjust offset while keeping RIT enabled
    /// try await rig.setRIT(RITXITState(enabled: true, offset: -200))
    /// ```
    public func setRIT(_ state: RITXITState) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsRIT else {
            throw RigError.unsupportedOperation("RIT not supported by \(radioName)")
        }

        try await proto.setRIT(state)
        // Invalidate cached RIT state
        await stateCache.invalidate("rit_state")
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset from the radio.
    ///
    /// - Parameter cached: Use cached value if available (default: true)
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support RIT
    ///
    /// # Caching
    /// RIT state is cached for 500ms to reduce serial queries. Set `cached` to false
    /// for the most current state.
    ///
    /// # Example
    /// ```swift
    /// let ritState = try await rig.getRIT()
    /// print("RIT: \(ritState.description)")  // "ON (+500 Hz)" or "OFF"
    ///
    /// if ritState.enabled {
    ///     print("RIT offset: \(ritState.offset) Hz")
    /// }
    /// ```
    public func getRIT(cached: Bool = true) async throws -> RITXITState {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsRIT else {
            throw RigError.unsupportedOperation("RIT not supported by \(radioName)")
        }

        if cached {
            return try await stateCache.get("rit_state", maxAge: 0.5) {
                try await proto.getRIT()
            }
        } else {
            await stateCache.invalidate("rit_state")
            return try await proto.getRIT()
        }
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// XIT allows fine-tuning of the transmitter frequency independently from the displayed
    /// VFO frequency. This is useful for:
    /// - Split operation in contests
    /// - Working stations on slightly different frequencies
    /// - Compensating for transmit frequency offsets
    ///
    /// Most radios support offsets between -9999 Hz and +9999 Hz.
    ///
    /// **Note:** Not all radios support separate XIT control. Some radios (like IC-7100)
    /// only support RIT, which affects both RX and TX when transmitting.
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support XIT
    ///
    /// # Example
    /// ```swift
    /// // Enable XIT with -1000 Hz offset for split operation
    /// try await rig.setXIT(RITXITState(enabled: true, offset: -1000))
    ///
    /// // Disable XIT
    /// try await rig.setXIT(.disabled)
    /// ```
    public func setXIT(_ state: RITXITState) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsXIT else {
            throw RigError.unsupportedOperation("XIT not supported by \(radioName)")
        }

        try await proto.setXIT(state)
        // Invalidate cached XIT state
        await stateCache.invalidate("xit_state")
    }

    /// Gets the current XIT state.
    ///
    /// Queries both XIT ON/OFF status and frequency offset from the radio.
    ///
    /// **Note:** Not all radios support separate XIT control. This will throw
    /// `unsupportedOperation` for radios that don't support XIT.
    ///
    /// - Parameter cached: Use cached value if available (default: true)
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support XIT
    ///
    /// # Caching
    /// XIT state is cached for 500ms to reduce serial queries. Set `cached` to false
    /// for the most current state.
    ///
    /// # Example
    /// ```swift
    /// let xitState = try await rig.getXIT()
    /// print("XIT: \(xitState.description)")  // "ON (-1000 Hz)" or "OFF"
    /// ```
    public func getXIT(cached: Bool = true) async throws -> RITXITState {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsXIT else {
            throw RigError.unsupportedOperation("XIT not supported by \(radioName)")
        }

        if cached {
            return try await stateCache.get("xit_state", maxAge: 0.5) {
                try await proto.getXIT()
            }
        } else {
            await stateCache.invalidate("xit_state")
            return try await proto.getXIT()
        }
    }

    // MARK: - DSP Controls

    /// Sets the AGC (Automatic Gain Control) speed.
    ///
    /// AGC controls how quickly the receiver responds to changes in signal strength.
    /// Different speeds are optimal for different operating modes:
    /// - **Fast**: Best for CW and digital modes where rapid signal changes occur
    /// - **Medium**: Good general-purpose setting for SSB and mixed modes
    /// - **Slow**: Preferred for weak signal SSB work and DXing
    /// - **Off**: Disables AGC for manual gain control (advanced users only)
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if AGC control not supported
    ///   - `RigError.invalidParameter` if speed not supported by this radio
    ///
    /// # Example
    /// ```swift
    /// // Fast AGC for CW operation
    /// try await rig.setAGC(.fast)
    ///
    /// // Slow AGC for weak signal SSB DXing
    /// try await rig.setAGC(.slow)
    ///
    /// // Medium AGC for general SSB
    /// try await rig.setAGC(.medium)
    /// ```
    ///
    /// # Radio Support
    /// AGC control is supported on most modern Icom radios:
    /// - IC-9700, IC-7610, IC-7300, IC-7600, IC-7100, IC-705
    /// - IC-7851, IC-7800, IC-7700
    ///
    /// Note: IC-7600/7300/7610/7851 do not support AGC OFF.
    public func setAGC(_ speed: AGCSpeed) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setAGC(speed)
        // Invalidate cached AGC setting
        await stateCache.invalidate("agc_speed")
    }

    /// Gets the current AGC speed.
    ///
    /// - Parameter cached: Whether to use cached value if available (defaults to true)
    /// - Returns: Current AGC speed setting
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if AGC control not supported
    ///
    /// # Caching
    /// When `cached` is true, the controller returns a cached AGC setting if available
    /// and less than 500ms old. Set `cached` to false to force a fresh query.
    ///
    /// # Example
    /// ```swift
    /// // Get current AGC setting
    /// let agc = try await rig.agc()
    /// print("Current AGC: \(agc.description)")  // "Fast AGC"
    ///
    /// // Force fresh query
    /// let freshAGC = try await rig.agc(cached: false)
    /// ```
    public func agc(cached: Bool = true) async throws -> AGCSpeed {
        guard connected else {
            throw RigError.notConnected
        }

        if cached {
            return try await stateCache.get("agc_speed", maxAge: 0.5) {
                try await proto.getAGC()
            }
        } else {
            await stateCache.invalidate("agc_speed")
            return try await proto.getAGC()
        }
    }

    /// Sets the noise blanker configuration.
    ///
    /// Noise blanker removes impulse noise such as power line noise, ignition noise,
    /// and static crashes. Different radios support different NB capabilities:
    /// - Some radios have simple on/off control
    /// - Others have adjustable NB level (0-255)
    ///
    /// - Parameter config: The desired noise blanker configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NB not supported
    ///   - `RigError.invalidParameter` if level out of range for this radio
    ///
    /// # Example
    /// ```swift
    /// // Enable NB with level 5
    /// try await rig.setNoiseBlanker(.enabled(level: 5))
    ///
    /// // Disable NB
    /// try await rig.setNoiseBlanker(.off)
    ///
    /// // Enable NB (radios without level control)
    /// try await rig.setNoiseBlanker(.enabled())
    /// ```
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setNoiseBlanker(config)
        await stateCache.invalidate("noise_blanker")
    }

    /// Gets the current noise blanker configuration.
    ///
    /// Returns the current NB state including level if the radio supports it.
    ///
    /// - Parameter cached: Whether to use cached value (default true)
    /// - Returns: Current noise blanker configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NB not supported
    ///
    /// # Example
    /// ```swift
    /// let nb = try await rig.noiseBlanker()
    /// if nb.isEnabled {
    ///     print("NB enabled, level: \(nb.level ?? 0)")
    /// }
    /// ```
    public func noiseBlanker(cached: Bool = true) async throws -> NoiseBlanker {
        guard connected else {
            throw RigError.notConnected
        }

        if cached {
            return try await stateCache.get("noise_blanker", maxAge: 0.5) {
                try await proto.getNoiseBlanker()
            }
        } else {
            await stateCache.invalidate("noise_blanker")
            return try await proto.getNoiseBlanker()
        }
    }

    /// Sets the noise reduction configuration.
    ///
    /// Noise reduction uses DSP filtering to reduce continuous background noise
    /// while preserving the desired signal. Higher levels provide better noise
    /// reduction but may affect audio fidelity.
    ///
    /// - Parameter config: The desired noise reduction configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NR not supported
    ///   - `RigError.invalidParameter` if level out of range for this radio
    ///
    /// # Example
    /// ```swift
    /// // Enable NR with level 8
    /// try await rig.setNoiseReduction(.enabled(level: 8))
    ///
    /// // Disable NR
    /// try await rig.setNoiseReduction(.off)
    ///
    /// // Maximum NR for weak signal work
    /// try await rig.setNoiseReduction(.enabled(level: 15))
    /// ```
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setNoiseReduction(config)
        await stateCache.invalidate("noise_reduction")
    }

    /// Gets the current noise reduction configuration.
    ///
    /// Returns the current NR state including level.
    ///
    /// - Parameter cached: Whether to use cached value (default true)
    /// - Returns: Current noise reduction configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NR not supported
    ///
    /// # Example
    /// ```swift
    /// let nr = try await rig.noiseReduction()
    /// if nr.isEnabled {
    ///     print("NR enabled, level: \(nr.level ?? 0)")
    /// }
    /// ```
    public func noiseReduction(cached: Bool = true) async throws -> NoiseReduction {
        guard connected else {
            throw RigError.notConnected
        }

        if cached {
            return try await stateCache.get("noise_reduction", maxAge: 0.5) {
                try await proto.getNoiseReduction()
            }
        } else {
            await stateCache.invalidate("noise_reduction")
            return try await proto.getNoiseReduction()
        }
    }

    // MARK: - Memory Channel Operations

    /// Stores a configuration to a memory channel.
    ///
    /// Writes the specified memory channel configuration to the radio's non-volatile memory.
    /// The channel can be recalled later for quick frequency/mode changes.
    ///
    /// - Parameter channel: Memory channel configuration to store
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory channels not supported
    ///   - `RigError.commandFailed` if radio rejects the channel configuration
    ///
    /// # Example
    /// ```swift
    /// // Create a memory channel for 20m FT8
    /// let channel = MemoryChannel(
    ///     number: 1,
    ///     frequency: 14_074_000,
    ///     mode: .dataUSB,
    ///     name: "20m FT8"
    /// )
    /// try await rig.setMemoryChannel(channel)
    /// ```
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        try await proto.setMemoryChannel(channel)
        // Invalidate cached channel data
        await stateCache.invalidate("mem_\(channel.number)")
    }

    /// Reads a memory channel configuration from the radio.
    ///
    /// Retrieves the stored configuration for the specified memory channel number.
    ///
    /// - Parameter number: Memory channel number to read
    /// - Returns: Memory channel configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory channels not supported
    ///   - `RigError.commandFailed` if channel is empty or invalid
    ///
    /// # Example
    /// ```swift
    /// let channel = try await rig.getMemoryChannel(1)
    /// print("Channel \(channel.number): \(channel.description)")
    /// // "Ch 1 (20m FT8): 14.074 MHz dataUSB"
    /// ```
    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        guard connected else {
            throw RigError.notConnected
        }

        return try await proto.getMemoryChannel(number)
    }

    /// Gets the total number of memory channels supported by the radio.
    ///
    /// Returns the maximum number of user-programmable memory channels.
    /// This may not include special channels (call channels, program scan edges, etc.).
    ///
    /// - Returns: Number of memory channels (e.g., 99, 100, 109)
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory not supported
    ///
    /// # Example
    /// ```swift
    /// let count = try await rig.memoryChannelCount()
    /// print("\(radioName) supports \(count) memory channels")
    /// ```
    public func memoryChannelCount() async throws -> Int {
        guard connected else {
            throw RigError.notConnected
        }

        return try await proto.getMemoryChannelCount()
    }

    /// Clears (erases) a memory channel.
    ///
    /// Removes the configuration from the specified memory channel, making it empty.
    ///
    /// - Parameter number: Memory channel number to clear
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory not supported
    ///   - `RigError.commandFailed` if operation fails
    ///
    /// # Example
    /// ```swift
    /// try await rig.clearMemoryChannel(1)
    /// ```
    public func clearMemoryChannel(_ number: Int) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        try await proto.clearMemoryChannel(number)
        // Invalidate cached channel data
        await stateCache.invalidate("mem_\(number)")
    }

    /// Recalls a memory channel configuration to the current VFO.
    ///
    /// Reads the specified memory channel and applies its frequency and mode to the current VFO.
    /// This is a convenience method that combines reading a channel and applying its settings.
    ///
    /// - Parameters:
    ///   - number: Memory channel number to recall
    ///   - vfo: Target VFO (default: .a)
    /// - Throws: `RigError` if operation fails or channel is empty
    ///
    /// # Example
    /// ```swift
    /// // Recall channel 1 settings to VFO A
    /// try await rig.recallMemoryChannel(1)
    /// ```
    public func recallMemoryChannel(_ number: Int, to vfo: VFO = .a) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        // Read the channel
        let channel = try await getMemoryChannel(number)

        // Apply frequency and mode to the specified VFO
        try await setFrequency(channel.frequency, vfo: vfo)
        try await setMode(channel.mode, vfo: vfo)
    }

    /// Stores the current VFO configuration to a memory channel.
    ///
    /// Creates a new memory channel from the current VFO's frequency and mode.
    /// Optionally specify a name and additional parameters.
    ///
    /// - Parameters:
    ///   - number: Memory channel number to store to
    ///   - vfo: Source VFO to read from (default: .a)
    ///   - name: Optional channel name (max 10 characters for Icom)
    /// - Throws: `RigError` if operation fails
    ///
    /// # Example
    /// ```swift
    /// // Store current VFO A settings to channel 5
    /// try await rig.storeCurrentToMemory(5, name: "Contest")
    /// ```
    public func storeCurrentToMemory(_ number: Int, from vfo: VFO = .a, name: String? = nil) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        // Read current VFO settings
        let frequency = try await self.frequency(vfo: vfo, cached: false)
        let mode = try await self.mode(vfo: vfo, cached: false)

        // Create and store channel
        let channel = MemoryChannel(
            number: number,
            frequency: frequency,
            mode: mode,
            name: name
        )

        try await setMemoryChannel(channel)
    }

    // MARK: - Batch Configuration

    /// Configure multiple radio parameters in one call.
    ///
    /// This is a convenience method for setting up the radio with multiple parameters
    /// in a single operation. All parameters are optional, and only specified parameters
    /// will be changed.
    ///
    /// - Parameters:
    ///   - frequency: Frequency in Hz (optional)
    ///   - mode: Operating mode (optional)
    ///   - vfo: Target VFO (default: .a)
    ///   - power: Transmit power in watts (optional)
    /// - Throws: `RigError` if any operation fails
    ///
    /// # Example
    /// ```swift
    /// // Set up for FT8 on 20m
    /// try await rig.configure(
    ///     frequency: 14_074_000,
    ///     mode: .dataUSB,
    ///     power: 50
    /// )
    ///
    /// // Quick band change
    /// try await rig.configure(frequency: 7_074_000)
    ///
    /// // Mode change only
    /// try await rig.configure(mode: .cw)
    /// ```
    public func configure(
        frequency: UInt64? = nil,
        mode: Mode? = nil,
        vfo: VFO = .a,
        power: Int? = nil
    ) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        // Apply in optimal order (frequency, mode, power)
        // This ensures mode filter settings are applied after frequency
        if let frequency = frequency {
            try await setFrequency(frequency, vfo: vfo)
        }

        if let mode = mode {
            try await setMode(mode, vfo: vfo)
        }

        if let power = power {
            try await setPower(power)
        }
    }

    // MARK: - Cache Management

    /// Manually invalidate all cached state.
    ///
    /// This forces all subsequent queries to fetch fresh data from the radio.
    /// Useful after manual radio adjustments or when cache inconsistency is suspected.
    ///
    /// - Example:
    /// ```swift
    /// // After manual radio adjustments
    /// await rig.invalidateCache()
    /// let freshFreq = try await rig.frequency()
    /// ```
    public func invalidateCache() async {
        await stateCache.invalidate()
    }

    /// Get cache statistics for debugging.
    ///
    /// - Returns: Statistics about the current cache state
    public func cacheStatistics() async -> CacheStatistics {
        await stateCache.statistics()
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
