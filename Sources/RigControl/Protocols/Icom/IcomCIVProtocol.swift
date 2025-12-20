import Foundation

/// Actor implementing the Icom CI-V protocol for radio control.
///
/// The CI-V (Computer Interface V) protocol is used by Icom transceivers for CAT control.
/// This implementation supports frequency, mode, PTT, VFO, and power control operations.
///
/// ## Architecture
/// Uses the CIVCommandSet protocol for radio-specific command formatting, allowing
/// clean separation between transport/framing logic and radio-specific quirks.
public actor IcomCIVProtocol: CATProtocol {
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The CI-V address of the radio (user-configurable, used for bus routing only)
    internal let civAddress: UInt8

    /// The radio model (determines command set, independent of CI-V address)
    public let radioModel: IcomRadioModel

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Radio-specific command set for formatting CI-V commands
    private let commandSet: any CIVCommandSet

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Initializes a new Icom CI-V protocol instance with a command set.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - civAddress: CI-V bus address (user-configurable, defaults to radio's default)
    ///   - radioModel: The specific radio model (determines command set)
    ///   - commandSet: Radio-specific command set for formatting commands
    ///   - capabilities: The capabilities of this radio model
    public init(
        transport: any SerialTransport,
        civAddress: UInt8? = nil,
        radioModel: IcomRadioModel,
        commandSet: any CIVCommandSet,
        capabilities: RigCapabilities
    ) {
        self.transport = transport
        self.radioModel = radioModel
        self.civAddress = civAddress ?? radioModel.defaultCIVAddress
        self.commandSet = commandSet
        self.capabilities = capabilities
    }

    /// Initializes a new Icom CI-V protocol instance (legacy compatibility).
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - civAddress: The CI-V address of the radio (e.g., 0xA2 for IC-9700)
    ///   - capabilities: The capabilities of this radio model
    @available(*, deprecated, message: "Use init(transport:civAddress:radioModel:commandSet:capabilities:) for better radio-specific support")
    public init(transport: any SerialTransport, civAddress: UInt8, capabilities: RigCapabilities) {
        self.transport = transport
        self.civAddress = civAddress
        self.capabilities = capabilities

        // Try to infer radio model from CI-V address (legacy behavior)
        // This is imperfect since addresses are user-configurable
        self.radioModel = IcomRadioModel.allCases.first { $0.defaultCIVAddress == civAddress } ?? .ic7300

        // Create a standard command set based on capabilities
        // Use targetable VFO model as legacy default
        self.commandSet = StandardIcomCommandSet(
            civAddress: civAddress,
            vfoModel: capabilities.requiresVFOSelection ? .targetable : .none,
            requiresModeFilter: capabilities.requiresModeFilter,
            echoesCommands: false  // Legacy default
        )
    }

    /// Required initializer from CATProtocol (throws since we need civAddress)
    public init(transport: any SerialTransport) {
        fatalError("Use init(transport:commandSet:capabilities:) for Icom radios")
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        // Flush any pending data
        try await transport.flush()
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // Select the appropriate VFO first (if radio requires AND supports it)
        // Some radios (IC-7600, IC-7100, IC-705) operate on current VFO/band only
        if capabilities.requiresVFOSelection, commandSet.selectVFOCommand(vfo) != nil {
            try await selectVFO(vfo)
        }

        // Get command formatting from command set
        let (command, data) = commandSet.setFrequencyCommand(frequency: hz)

        let frame = CIVFrame(
            to: civAddress,
            command: command,
            data: data
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected frequency \(hz) Hz")
        }
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        // Select the appropriate VFO first (if radio requires AND supports it)
        // Some radios (IC-7600, IC-7100, IC-705) operate on current VFO/band only
        if capabilities.requiresVFOSelection, commandSet.selectVFOCommand(vfo) != nil {
            try await selectVFO(vfo)
        }

        // Get command formatting from command set
        let command = commandSet.readFrequencyCommand()

        let frame = CIVFrame(
            to: civAddress,
            command: command
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Parse response using command set
        return try commandSet.parseFrequencyResponse(response)
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        // Select the appropriate VFO first (if radio requires AND supports it)
        // Some radios (IC-7600, IC-7100, IC-705) operate on current VFO/band only
        if capabilities.requiresVFOSelection, commandSet.selectVFOCommand(vfo) != nil {
            try await selectVFO(vfo)
        }

        // Convert Mode enum to Icom mode code
        let modeCode = try modeToIcomCode(mode)

        // Get command formatting from command set
        let (command, data) = commandSet.setModeCommand(mode: modeCode)

        let frame = CIVFrame(
            to: civAddress,
            command: command,
            data: data
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected mode \(mode)")
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        // Select the appropriate VFO first (if radio requires AND supports it)
        // Some radios (IC-7600, IC-7100, IC-705) operate on current VFO/band only
        if capabilities.requiresVFOSelection, commandSet.selectVFOCommand(vfo) != nil {
            try await selectVFO(vfo)
        }

        // Get command formatting from command set
        let command = commandSet.readModeCommand()

        let frame = CIVFrame(
            to: civAddress,
            command: command
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Parse response using command set
        let modeCode = try commandSet.parseModeResponse(response)
        return try icomCodeToMode(modeCode)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Get command formatting from command set
        let (command, data) = commandSet.setPTTCommand(enabled: enabled)

        let frame = CIVFrame(
            to: civAddress,
            command: command,
            data: data
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected PTT \(enabled ? "on" : "off")")
        }
    }

    public func getPTT() async throws -> Bool {
        // Get command formatting from command set
        let command = commandSet.readPTTCommand()

        let frame = CIVFrame(
            to: civAddress,
            command: command
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Parse response using command set
        return try commandSet.parsePTTResponse(response)
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        let vfoCode: UInt8
        switch vfo {
        case .a:
            vfoCode = CIVFrame.VFOSelect.vfoA
        case .b:
            vfoCode = CIVFrame.VFOSelect.vfoB
        case .main:
            vfoCode = CIVFrame.VFOSelect.main
        case .sub:
            vfoCode = CIVFrame.VFOSelect.sub
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [vfoCode]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected VFO selection")
        }
    }

    // MARK: - Power Control

    public func setPower(_ value: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Get command formatting from command set
        let (command, data) = commandSet.setPowerCommand(value: value)

        let frame = CIVFrame(
            to: civAddress,
            command: command,
            data: data
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected power setting")
        }
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Get command formatting from command set
        let command = commandSet.readPowerCommand()

        let frame = CIVFrame(
            to: civAddress,
            command: command
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Parse response using command set
        return try commandSet.parsePowerResponse(response)
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        // Build and send command
        // Command 0x0F, data 0x01 for split on, 0x00 for split off
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.split],
            data: [enabled ? 0x01 : 0x00]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected split \(enabled ? "on" : "off")")
        }
    }

    public func getSplit() async throws -> Bool {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        // Build and send query command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.split]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.command[0] == CIVFrame.Command.split,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }

        return response.data[0] == 0x01
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Build and send query command
        // Command 0x15 (read level), sub-command 0x02 (S-meter)
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readLevel, CIVFrame.LevelRead.sMeter]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Response should contain command echo and BCD data
        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.readLevel,
              response.command[1] == CIVFrame.LevelRead.sMeter,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }

        // Decode BCD value (2 bytes, little-endian)
        // Range: 0x0000 to 0x0255 (0-241 in decimal)
        let rawValue = BCDEncoding.decodePower(response.data)

        // Convert to S-units
        // Roughly 24 units per S-unit (0-241 range / 10 S-units ≈ 24)
        // S0-S8: every 24 units
        // S9: at 216 units (9 × 24)
        // S9+: above 216, each 4 units = 1 dB
        let sUnits = min(rawValue / 24, 9)
        let overS9 = sUnits >= 9 ? min((rawValue - 216) / 4, 60) : 0

        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
    }

    // MARK: - Private Methods

    /// Sends a CI-V frame to the radio.
    internal func sendFrame(_ frame: CIVFrame) async throws {
        let data = Data(frame.bytes())
        try await transport.write(data)
    }

    /// Receives a CI-V frame from the radio.
    /// Automatically skips echo frames for radios that echo commands (determined by command set).
    internal func receiveFrame() async throws -> CIVFrame {
        // Read until terminator (0xFD)
        let data = try await transport.readUntil(
            terminator: CIVFrame.terminator,
            timeout: responseTimeout
        )

        let frame = try CIVFrame.parse(data)

        // If this radio echoes commands and this is an echo frame, read the next frame (actual response)
        if commandSet.echoesCommands && frame.isEcho {
            let nextData = try await transport.readUntil(
                terminator: CIVFrame.terminator,
                timeout: responseTimeout
            )
            return try CIVFrame.parse(nextData)
        }

        return frame
    }

    /// Converts a Mode enum to an Icom mode code.
    private func modeToIcomCode(_ mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb: return CIVFrame.ModeCode.lsb
        case .usb: return CIVFrame.ModeCode.usb
        case .am: return CIVFrame.ModeCode.am
        case .cw: return CIVFrame.ModeCode.cw
        case .cwR: return CIVFrame.ModeCode.cwR
        case .rtty: return CIVFrame.ModeCode.rtty
        case .rttyR: return CIVFrame.ModeCode.rttyR
        case .fm: return CIVFrame.ModeCode.fm
        case .wfm: return CIVFrame.ModeCode.wfm
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Icom protocol")
        }
    }

    /// Converts an Icom mode code to a Mode enum.
    private func icomCodeToMode(_ code: UInt8) throws -> Mode {
        switch code {
        case CIVFrame.ModeCode.lsb: return .lsb
        case CIVFrame.ModeCode.usb: return .usb
        case CIVFrame.ModeCode.am: return .am
        case CIVFrame.ModeCode.cw: return .cw
        case CIVFrame.ModeCode.cwR: return .cwR
        case CIVFrame.ModeCode.rtty: return .rtty
        case CIVFrame.ModeCode.rttyR: return .rttyR
        case CIVFrame.ModeCode.fm: return .fm
        case CIVFrame.ModeCode.wfm: return .wfm
        default:
            throw RigError.invalidResponse
        }
    }

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// RIT allows fine-tuning of the receiver frequency independently from the displayed
    /// VFO frequency. Most Icom radios support ±9999 Hz offset.
    ///
    /// Uses CI-V commands:
    /// - 0x21 0x00: Set RIT frequency offset (±9999 Hz)
    /// - 0x21 0x01: Set RIT ON/OFF
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or radio doesn't support RIT
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Set RIT offset first (even if disabling, some radios require this)
        let offsetBCD = BCDEncoding.encodeRITXITOffset(state.offset)
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritFrequency],
            data: offsetBCD
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        guard offsetResponse.isAck else {
            throw RigError.commandFailed("Radio rejected RIT offset \(state.offset) Hz")
        }

        // Set RIT ON/OFF
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritOnOff],
            data: [state.enabled ? 0x01 : 0x00]
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        guard enableResponse.isAck else {
            throw RigError.commandFailed("Radio rejected RIT \(state.enabled ? "enable" : "disable")")
        }
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset.
    ///
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails or radio doesn't support RIT
    public func getRIT() async throws -> RITXITState {
        // Read RIT ON/OFF status
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritOnOff],
            data: []
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        guard enableResponse.command.count >= 2,
              enableResponse.command[0] == CIVFrame.Command.ritXit,
              enableResponse.command[1] == CIVFrame.RITXITCode.ritOnOff,
              !enableResponse.data.isEmpty else {
            throw RigError.invalidResponse
        }

        let enabled = enableResponse.data[0] == 0x01

        // Read RIT frequency offset
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritFrequency],
            data: []
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        guard offsetResponse.command.count >= 2,
              offsetResponse.command[0] == CIVFrame.Command.ritXit,
              offsetResponse.command[1] == CIVFrame.RITXITCode.ritFrequency,
              offsetResponse.data.count == 3 else {
            throw RigError.invalidResponse
        }

        let offset = try BCDEncoding.decodeRITXITOffset(offsetResponse.data)

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// XIT allows fine-tuning of the transmitter frequency independently from the displayed
    /// VFO frequency. Most Icom radios support ±9999 Hz offset.
    ///
    /// **Note:** Not all Icom radios support separate XIT control. Some radios (like IC-7100)
    /// only support RIT, which affects both RX and TX when transmitting.
    ///
    /// Uses CI-V commands:
    /// - 0x21 0x02: Set XIT frequency offset (±9999 Hz) - if supported
    /// - 0x21 0x03: Set XIT ON/OFF - if supported
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or radio doesn't support XIT
    public func setXIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("XIT offset must be between -9999 and +9999 Hz")
        }

        // Set XIT offset first
        let offsetBCD = BCDEncoding.encodeRITXITOffset(state.offset)
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitFrequency],
            data: offsetBCD
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        // Check if radio supports XIT
        if offsetResponse.isNak {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }

        guard offsetResponse.isAck else {
            throw RigError.commandFailed("Radio rejected XIT offset \(state.offset) Hz")
        }

        // Set XIT ON/OFF
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitOnOff],
            data: [state.enabled ? 0x01 : 0x00]
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        guard enableResponse.isAck else {
            throw RigError.commandFailed("Radio rejected XIT \(state.enabled ? "enable" : "disable")")
        }
    }

    /// Gets the current XIT state.
    ///
    /// Queries both XIT ON/OFF status and frequency offset.
    ///
    /// **Note:** Not all Icom radios support separate XIT control. This will throw
    /// `unsupportedOperation` for radios that don't support XIT.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails or radio doesn't support XIT
    public func getXIT() async throws -> RITXITState {
        // Read XIT ON/OFF status
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitOnOff],
            data: []
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        // Check if radio supports XIT
        if enableResponse.isNak {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }

        guard enableResponse.command.count >= 2,
              enableResponse.command[0] == CIVFrame.Command.ritXit,
              enableResponse.command[1] == CIVFrame.RITXITCode.xitOnOff,
              !enableResponse.data.isEmpty else {
            throw RigError.invalidResponse
        }

        let enabled = enableResponse.data[0] == 0x01

        // Read XIT frequency offset
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitFrequency],
            data: []
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        guard offsetResponse.command.count >= 2,
              offsetResponse.command[0] == CIVFrame.Command.ritXit,
              offsetResponse.command[1] == CIVFrame.RITXITCode.xitFrequency,
              offsetResponse.data.count == 3 else {
            throw RigError.invalidResponse
        }

        let offset = try BCDEncoding.decodeRITXITOffset(offsetResponse.data)

        return RITXITState(enabled: enabled, offset: offset)
    }

    // MARK: - Memory Channel Operations

    /// Stores a configuration to a memory channel.
    ///
    /// Uses CI-V command 0x1A 0x00 (Advanced Settings - Memory Contents) to write a complete
    /// memory channel configuration including frequency, mode, filter, name, and optional features.
    ///
    /// - Parameter channel: Memory channel configuration to store
    /// - Throws: `RigError` if operation fails or channel number is invalid
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        // Validate channel configuration
        try channel.validate(for: capabilities)

        // Encode channel data to CI-V format
        var data = [UInt8]()

        // Channel number (2 bytes BCD)
        data.append(contentsOf: encodeChannelNumber(channel.number))

        // Frequency (5 bytes BCD)
        data.append(contentsOf: BCDEncoding.encodeFrequency(channel.frequency))

        // Mode (1 byte)
        let modeCode = try modeToIcomCode(channel.mode)
        data.append(modeCode)

        // Filter selection (1 byte)
        data.append(UInt8(channel.filterSelection ?? 1))

        // Data mode (1 byte) - 0x00 = off, 0x01 = on
        data.append((channel.dataMode ?? false) ? 0x01 : 0x00)

        // Duplex offset (3 bytes BCD, signed)
        data.append(contentsOf: encodeDuplexOffset(channel.duplexOffset ?? 0))

        // CTCSS/DCS tone (2 bytes) - simplified, 0x0000 = none
        data.append(contentsOf: encodeToneFrequency(channel.toneFrequency))

        // Channel name (10 bytes ASCII, space-padded)
        data.append(contentsOf: encodeChannelName(channel.name))

        // Build and send memory write command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.memoryContents],
            data: data
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected memory channel \(channel.number) write")
        }
    }

    /// Reads a memory channel configuration from the radio.
    ///
    /// Uses CI-V command 0x1A 0x00 (Advanced Settings - Memory Contents) to read a complete
    /// memory channel configuration.
    ///
    /// - Parameter number: Memory channel number to read
    /// - Returns: Memory channel configuration
    /// - Throws: `RigError` if operation fails, channel is empty, or number is invalid
    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        // Build query command with channel number
        let channelBCD = encodeChannelNumber(number)

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.memoryContents],
            data: channelBCD
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Check for NAK (channel empty or invalid)
        if response.isNak {
            throw RigError.commandFailed("Memory channel \(number) is empty or invalid")
        }

        // Parse response data
        // Expected: [channel 2] [freq 5] [mode 1] [filter 1] [data mode 1] [duplex 3] [tone 2] [name 10]
        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.advancedSettings,
              response.command[1] == CIVFrame.AdvancedCode.memoryContents,
              response.data.count >= 25 else {
            throw RigError.invalidResponse
        }

        let data = response.data

        // Decode channel number (bytes 0-1, already validated)
        // Skip decoding, we know it matches 'number'

        // Decode frequency (bytes 2-6)
        let frequency = try BCDEncoding.decodeFrequency(Array(data[2..<7]))

        // Decode mode (byte 7)
        let modeCode = data[7]
        let mode = try icomCodeToMode(modeCode)

        // Decode filter selection (byte 8)
        let filterSelection = Int(data[8])

        // Decode data mode (byte 9)
        let dataMode = data[9] == 0x01

        // Decode duplex offset (bytes 10-12)
        let duplexOffset = decodeDuplexOffset(Array(data[10..<13]))

        // Decode tone frequency (bytes 13-14)
        let toneFrequency = decodeToneFrequency(Array(data[13..<15]))

        // Decode channel name (bytes 15-24)
        let name = decodeChannelName(Array(data[15..<25]))

        return MemoryChannel(
            number: number,
            frequency: frequency,
            mode: mode,
            name: name,
            splitEnabled: nil,  // Not stored in basic memory format
            txFrequency: nil,   // Not stored in basic memory format
            toneFrequency: toneFrequency,
            toneSqelchFrequency: nil,  // Not differentiated in basic format
            dcsCode: nil,       // Would require separate parsing
            duplexOffset: duplexOffset != 0 ? duplexOffset : nil,
            skipScan: nil,      // Not stored in basic memory format
            lockout: nil,       // Not stored in basic memory format
            filterSelection: filterSelection != 0 ? filterSelection : nil,
            dataMode: dataMode ? true : nil,
            powerLevel: nil     // Not stored in basic memory format
        )
    }

    /// Gets the total number of memory channels supported by the radio.
    ///
    /// Returns model-specific channel counts. Actual channel numbering may start at 0 or 1
    /// depending on the radio model.
    ///
    /// - Returns: Number of memory channels
    /// - Throws: `RigError.unsupportedOperation` if memory not supported
    public func getMemoryChannelCount() async throws -> Int {
        // Return model-specific channel count
        // Common values: 99 (most radios), 100 (IC-7600), 109 (IC-7100/9700)
        switch radioModel {
        case .ic7300, .ic705, .ic703:
            return 99
        case .xieguG90, .xieguX6100, .xieguX6200:
            return 99  // Xiegu radios use 1-99 memory channels
        case .ic7600:
            return 100
        case .ic7100, .ic9700:
            return 109  // Includes program scan edges and call channels
        case .ic9100, .ic7000:
            return 99
        case .ic7610, .ic7700, .ic7410, .ic7200, .ic718:
            return 99
        case .ic7851, .ic7850, .ic7800:
            return 99
        case .ic756proIII, .ic756proII, .ic756pro, .ic756:
            return 99
        case .ic746pro, .ic746:
            return 99
        case .ic706mkiig, .ic706mkii, .ic706:
            return 99
        case .ic910h, .ic9000, .ic820h:
            return 99
        case .ic275, .ic375, .ic475:
            return 99
        case .ic2730, .ic2820h:
            return 99
        case .id5100, .id4100:
            return 99
        case .icr8600, .icr75, .icr30, .icr9500:
            return 99
        }
    }

    /// Clears (erases) a memory channel.
    ///
    /// Uses CI-V command 0x0B (Memory Clear) to erase the specified channel.
    ///
    /// - Parameter number: Memory channel number to clear
    /// - Throws: `RigError` if operation fails or number is invalid
    public func clearMemoryChannel(_ number: Int) async throws {
        // Build clear command with channel number
        let channelBCD = encodeChannelNumber(number)

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.memoryClear],
            data: channelBCD
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected memory channel \(number) clear")
        }
    }

    // MARK: - Memory Channel Encoding/Decoding Helpers

    /// Encodes a channel number to 2-byte BCD format.
    ///
    /// - Parameter number: Channel number (0-999)
    /// - Returns: 2-byte BCD representation [low, high]
    private func encodeChannelNumber(_ number: Int) -> [UInt8] {
        let low = UInt8((number % 10) | ((number / 10 % 10) << 4))
        let high = UInt8((number / 100 % 10) | ((number / 1000 % 10) << 4))
        return [low, high]
    }

    /// Encodes a duplex offset to 3-byte signed BCD format.
    ///
    /// - Parameter offset: Offset in Hz (negative for -, positive for +, 0 for simplex)
    /// - Returns: 3-byte BCD representation with sign bit
    private func encodeDuplexOffset(_ offset: Int) -> [UInt8] {
        if offset == 0 {
            return [0x00, 0x00, 0x00]
        }

        let absOffset = abs(offset)
        let low = UInt8((absOffset % 10) | ((absOffset / 10 % 10) << 4))
        let mid = UInt8((absOffset / 100 % 10) | ((absOffset / 1000 % 10) << 4))
        let high = UInt8((absOffset / 10000 % 10) | ((absOffset / 100000 % 10) << 4))

        // Sign bit in MSB of high byte
        let signBit: UInt8 = offset < 0 ? 0x80 : 0x00

        return [low, mid, high | signBit]
    }

    /// Decodes a 3-byte signed BCD duplex offset.
    ///
    /// - Parameter data: 3-byte BCD data
    /// - Returns: Offset in Hz (negative for -, positive for +)
    private func decodeDuplexOffset(_ data: [UInt8]) -> Int {
        guard data.count >= 3 else { return 0 }

        let low = data[0]
        let mid = data[1]
        let high = data[2]

        // Extract sign bit
        let isNegative = (high & 0x80) != 0
        let highCleaned = high & 0x7F

        let offset = Int(low & 0x0F) +
                     Int((low >> 4) & 0x0F) * 10 +
                     Int(mid & 0x0F) * 100 +
                     Int((mid >> 4) & 0x0F) * 1000 +
                     Int(highCleaned & 0x0F) * 10000 +
                     Int((highCleaned >> 4) & 0x0F) * 100000

        return isNegative ? -offset : offset
    }

    /// Encodes a CTCSS tone frequency to 2-byte format.
    ///
    /// - Parameter frequency: Tone frequency in Hz (67.0-254.1), or nil for no tone
    /// - Returns: 2-byte tone representation (0x0000 for none)
    private func encodeToneFrequency(_ frequency: Double?) -> [UInt8] {
        guard let freq = frequency else {
            return [0x00, 0x00]
        }

        // Convert frequency to BCD (multiply by 10 to preserve decimal)
        let toneValue = Int(freq * 10)
        let low = UInt8((toneValue % 10) | ((toneValue / 10 % 10) << 4))
        let high = UInt8((toneValue / 100 % 10) | ((toneValue / 1000 % 10) << 4))

        return [low, high]
    }

    /// Decodes a 2-byte CTCSS tone frequency.
    ///
    /// - Parameter data: 2-byte tone data
    /// - Returns: Tone frequency in Hz, or nil if no tone set
    private func decodeToneFrequency(_ data: [UInt8]) -> Double? {
        guard data.count >= 2 else { return nil }

        let low = data[0]
        let high = data[1]

        // Check for no tone
        if low == 0x00 && high == 0x00 {
            return nil
        }

        let toneValue = Int(low & 0x0F) +
                        Int((low >> 4) & 0x0F) * 10 +
                        Int(high & 0x0F) * 100 +
                        Int((high >> 4) & 0x0F) * 1000

        return Double(toneValue) / 10.0
    }

    /// Encodes a channel name to 10-byte space-padded ASCII.
    ///
    /// - Parameter name: Channel name (max 10 characters), or nil for unnamed
    /// - Returns: 10-byte ASCII representation
    private func encodeChannelName(_ name: String?) -> [UInt8] {
        var nameBytes = [UInt8](repeating: 0x20, count: 10)  // Space-padded

        if let name = name {
            let truncated = String(name.prefix(10))
            let ascii = truncated.data(using: .ascii) ?? Data()
            for (i, byte) in ascii.enumerated() where i < 10 {
                nameBytes[i] = byte
            }
        }

        return nameBytes
    }

    /// Decodes a 10-byte space-padded ASCII channel name.
    ///
    /// - Parameter data: 10-byte name data
    /// - Returns: Channel name string, or nil if all spaces
    private func decodeChannelName(_ data: [UInt8]) -> String? {
        guard data.count >= 10 else { return nil }

        let nameData = Data(data[0..<10])
        guard let name = String(data: nameData, encoding: .ascii) else {
            return nil
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
