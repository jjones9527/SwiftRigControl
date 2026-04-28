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
    /// The unit and range depend on the radio's protocol. Icom CI-V radios use a
    /// 0–255 percentage scale (see `RigCapabilities.powerUnits`), not watts.
    /// Check `RigCapabilities` for the specific radio's power representation.
    ///
    /// - Parameter watts: Power level in the radio's native units (0 to capabilities.maxPower)
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

    // MARK: - DSP Controls

    /// Sets the AGC (Automatic Gain Control) speed.
    ///
    /// AGC controls how quickly the receiver responds to changes in signal strength.
    /// Different speeds are optimal for different operating modes:
    /// - **Fast**: Best for CW and digital modes
    /// - **Medium**: Good general-purpose setting for SSB
    /// - **Slow**: Preferred for weak signal SSB work and DXing
    /// - **Off**: Disables AGC for manual gain control
    ///
    /// # Example
    /// ```swift
    /// // Set fast AGC for CW operation
    /// try await protocol.setAGC(.fast)
    ///
    /// // Set slow AGC for weak signal SSB
    /// try await protocol.setAGC(.slow)
    /// ```
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws: `RigError.unsupportedOperation` if AGC control not supported
    /// - Throws: `RigError.invalidParameter` if speed not supported by this radio
    func setAGC(_ speed: AGCSpeed) async throws

    /// Gets the current AGC speed.
    ///
    /// - Returns: Current AGC speed setting
    /// - Throws: `RigError.unsupportedOperation` if AGC control not supported
    func getAGC() async throws -> AGCSpeed

    /// Sets the noise blanker configuration.
    ///
    /// Noise blanker removes impulse noise such as power line noise, ignition noise,
    /// and static crashes. Different radios support different NB capabilities:
    /// - Some radios have simple on/off control
    /// - Others have adjustable NB level (0-10)
    ///
    /// # Example
    /// ```swift
    /// // Enable NB with level 5
    /// try await protocol.setNoiseBlanker(.enabled(level: 5))
    ///
    /// // Disable NB
    /// try await protocol.setNoiseBlanker(.off)
    /// ```
    ///
    /// - Parameter config: The desired noise blanker configuration
    /// - Throws: `RigError.unsupportedOperation` if NB not supported
    /// - Throws: `RigError.invalidParameter` if level out of range for this radio
    func setNoiseBlanker(_ config: NoiseBlanker) async throws

    /// Gets the current noise blanker configuration.
    ///
    /// - Returns: Current noise blanker setting
    /// - Throws: `RigError.unsupportedOperation` if NB not supported
    func getNoiseBlanker() async throws -> NoiseBlanker

    /// Sets the noise reduction configuration.
    ///
    /// Noise reduction uses DSP filtering to reduce continuous background noise
    /// while preserving the desired signal. Higher levels provide better noise
    /// reduction but may affect audio fidelity.
    ///
    /// # Example
    /// ```swift
    /// // Enable NR with level 8
    /// try await protocol.setNoiseReduction(.enabled(level: 8))
    ///
    /// // Disable NR
    /// try await protocol.setNoiseReduction(.off)
    /// ```
    ///
    /// - Parameter config: The desired noise reduction configuration
    /// - Throws: `RigError.unsupportedOperation` if NR not supported
    /// - Throws: `RigError.invalidParameter` if level out of range for this radio
    func setNoiseReduction(_ config: NoiseReduction) async throws

    /// Gets the current noise reduction configuration.
    ///
    /// - Returns: Current noise reduction setting
    /// - Throws: `RigError.unsupportedOperation` if NR not supported
    func getNoiseReduction() async throws -> NoiseReduction

    /// Sets the IF (Intermediate Frequency) filter selection.
    ///
    /// Selects which of the radio's preset IF filters to use (FIL1/FIL2/FIL3).
    /// Each mode has independent filter settings. Narrower filters reduce adjacent
    /// channel interference but may affect audio quality.
    ///
    /// # Example
    /// ```swift
    /// // Select narrow filter for weak signal work
    /// try await protocol.setIFFilter(.filter3)
    ///
    /// // Select default filter
    /// try await protocol.setIFFilter(.filter1)
    /// ```
    ///
    /// - Parameter filter: The filter to select (filter1/filter2/filter3)
    /// - Throws: `RigError.unsupportedOperation` if IF filter control not supported
    func setIFFilter(_ filter: IFFilter) async throws

    /// Gets the current IF filter selection.
    ///
    /// - Returns: Current IF filter setting
    /// - Throws: `RigError.unsupportedOperation` if IF filter control not supported
    func getIFFilter() async throws -> IFFilter

    // MARK: - AF / RF / Squelch / Preamp / Attenuator

    /// Sets the AF (audio) output gain.
    ///
    /// Controls the speaker/headphone volume level using a 0–255 scale.
    /// Maps to CI-V command `0x14 0x01` on Icom radios.
    ///
    /// - Parameter level: Gain level from 0 (mute) to 255 (maximum)
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func setAFGain(_ level: Int) async throws

    /// Gets the current AF (audio) output gain.
    ///
    /// - Returns: Gain level from 0 to 255
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func getAFGain() async throws -> Int

    /// Sets the RF (receiver) gain.
    ///
    /// Controls the sensitivity of the receiver's RF front end.
    /// Lower values reduce sensitivity and help prevent overloading from strong nearby signals.
    /// Maps to CI-V command `0x14 0x02` on Icom radios.
    ///
    /// - Parameter level: Gain level from 0 (minimum) to 255 (maximum)
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func setRFGain(_ level: Int) async throws

    /// Gets the current RF (receiver) gain.
    ///
    /// - Returns: Gain level from 0 to 255
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func getRFGain() async throws -> Int

    /// Sets the squelch level.
    ///
    /// On FM/VHF/UHF radios this is the carrier squelch threshold.
    /// On HF radios it may control a noise or S-meter squelch.
    /// Maps to CI-V command `0x14 0x03` on Icom radios.
    ///
    /// - Parameter level: Squelch level from 0 (open) to 255 (maximum / tightest)
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func setSquelch(_ level: Int) async throws

    /// Gets the current squelch level.
    ///
    /// - Returns: Squelch level from 0 to 255
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func getSquelch() async throws -> Int

    /// Sets the preamplifier stage.
    ///
    /// Enables an RF preamplifier to boost weak-signal receive sensitivity.
    /// Not all radios have two preamp stages; check `RigCapabilities`.
    /// Maps to CI-V command `0x16 0x02` on Icom radios.
    ///
    /// - Parameter level: 0 = off, 1 = Preamp 1 (+10 dB), 2 = Preamp 2 (+20 dB)
    /// - Throws: `RigError.unsupportedOperation` if not supported
    /// - Throws: `RigError.invalidParameter` if level is out of range for this radio
    func setPreamp(_ level: Int) async throws

    /// Gets the current preamplifier state.
    ///
    /// - Returns: 0 = off, 1 = Preamp 1, 2 = Preamp 2
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func getPreamp() async throws -> Int

    /// Sets the front-end attenuator.
    ///
    /// Reduces the RF gain ahead of the first mixer to prevent overloading from strong signals.
    /// Available steps vary by radio model (typically 0, 6, 12, 18 dB).
    /// Maps to CI-V command `0x11` on Icom radios.
    ///
    /// - Parameter dB: Attenuation in dB — 0 (off) or a model-specific value (6, 12, 18, 20)
    /// - Throws: `RigError.unsupportedOperation` if not supported
    /// - Throws: `RigError.invalidParameter` if the dB value is not supported by this radio
    func setAttenuator(_ dB: Int) async throws

    /// Gets the current attenuator level.
    ///
    /// - Returns: Attenuation in dB (0 = off)
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func getAttenuator() async throws -> Int

    // MARK: - Power State

    /// Powers the radio on or puts it in standby mode.
    ///
    /// Not all radios support remote power control via CAT.
    /// Some support standby (low-power state) but not full power-off/on.
    /// Maps to CI-V command `0x18` on Icom radios.
    ///
    /// - Parameter on: `true` to power on / wake from standby, `false` for standby/off
    /// - Throws: `RigError.unsupportedOperation` if the radio does not support remote power control
    func setPowerState(_ on: Bool) async throws

    /// Gets the current power state of the radio.
    ///
    /// Implementations typically probe the radio with a lightweight read command;
    /// a successful response means the radio is on, a timeout means it is off or in standby.
    ///
    /// - Returns: `true` if the radio is powered on and responding
    /// - Throws: `RigError.unsupportedOperation` if not supported
    func getPowerState() async throws -> Bool

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

    /// Default implementation throws unsupported error
    public func setAGC(_ speed: AGCSpeed) async throws {
        throw RigError.unsupportedOperation("AGC (Automatic Gain Control) not supported")
    }

    /// Default implementation throws unsupported error
    public func getAGC() async throws -> AGCSpeed {
        throw RigError.unsupportedOperation("AGC (Automatic Gain Control) not supported")
    }

    /// Default implementation throws unsupported error
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        throw RigError.unsupportedOperation("Noise blanker not supported")
    }

    /// Default implementation throws unsupported error
    public func getNoiseBlanker() async throws -> NoiseBlanker {
        throw RigError.unsupportedOperation("Noise blanker not supported")
    }

    /// Default implementation throws unsupported error
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        throw RigError.unsupportedOperation("Noise reduction not supported")
    }

    /// Default implementation throws unsupported error
    public func getNoiseReduction() async throws -> NoiseReduction {
        throw RigError.unsupportedOperation("Noise reduction not supported")
    }

    /// Default implementation throws unsupported error
    public func setIFFilter(_ filter: IFFilter) async throws {
        throw RigError.unsupportedOperation("IF filter control not supported")
    }

    /// Default implementation throws unsupported error
    public func getIFFilter() async throws -> IFFilter {
        throw RigError.unsupportedOperation("IF filter control not supported")
    }

    /// Default implementation throws unsupported error
    public func setAFGain(_ level: Int) async throws {
        throw RigError.unsupportedOperation("AF gain control not supported")
    }

    /// Default implementation throws unsupported error
    public func getAFGain() async throws -> Int {
        throw RigError.unsupportedOperation("AF gain control not supported")
    }

    /// Default implementation throws unsupported error
    public func setRFGain(_ level: Int) async throws {
        throw RigError.unsupportedOperation("RF gain control not supported")
    }

    /// Default implementation throws unsupported error
    public func getRFGain() async throws -> Int {
        throw RigError.unsupportedOperation("RF gain control not supported")
    }

    /// Default implementation throws unsupported error
    public func setSquelch(_ level: Int) async throws {
        throw RigError.unsupportedOperation("Squelch control not supported")
    }

    /// Default implementation throws unsupported error
    public func getSquelch() async throws -> Int {
        throw RigError.unsupportedOperation("Squelch control not supported")
    }

    /// Default implementation throws unsupported error
    public func setPreamp(_ level: Int) async throws {
        throw RigError.unsupportedOperation("Preamp control not supported")
    }

    /// Default implementation throws unsupported error
    public func getPreamp() async throws -> Int {
        throw RigError.unsupportedOperation("Preamp control not supported")
    }

    /// Default implementation throws unsupported error
    public func setAttenuator(_ dB: Int) async throws {
        throw RigError.unsupportedOperation("Attenuator control not supported")
    }

    /// Default implementation throws unsupported error
    public func getAttenuator() async throws -> Int {
        throw RigError.unsupportedOperation("Attenuator control not supported")
    }

    /// Default implementation throws unsupported error
    public func setPowerState(_ on: Bool) async throws {
        throw RigError.unsupportedOperation("Remote power control not supported")
    }

    /// Default implementation throws unsupported error
    public func getPowerState() async throws -> Bool {
        throw RigError.unsupportedOperation("Remote power state query not supported")
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
