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
    internal let commandSet: any CIVCommandSet

    /// Default timeout for radio responses
    internal let responseTimeout: TimeInterval = 1.0

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

    /// Required by `CATProtocol` but not usable for Icom radios.
    ///
    /// Always triggers a `fatalError` at runtime. This initializer exists only to satisfy the
    /// `CATProtocol` requirement; all call-sites must use
    /// `init(transport:civAddress:radioModel:commandSet:capabilities:)` instead.
    ///
    /// - Important: Do not call this initializer directly. Use the designated Icom initializer.
    public init(transport: any SerialTransport) {
        preconditionFailure("Use init(transport:civAddress:radioModel:commandSet:capabilities:) for Icom radios")
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

        // Data modes use filter byte 0x00; voice/CW/RTTY modes use the command set default (FIL1)
        let frame: CIVFrame
        if isDataMode(mode) && capabilities.requiresModeFilter {
            // DATA mode: send mode byte + filter byte 0x00 (FilterCode.data)
            // This tells the radio to engage the DATA sub-mode (flat audio path)
            frame = CIVFrame(
                to: civAddress,
                command: [CIVFrame.Command.setMode],
                data: [modeCode, CIVFrame.FilterCode.data]
            )
        } else {
            // Voice/CW/RTTY mode: delegate to command set (handles filter byte presence per radio)
            let (command, data) = commandSet.setModeCommand(mode: modeCode)
            frame = CIVFrame(
                to: civAddress,
                command: command,
                data: data
            )
        }

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

        // Parse mode code from response
        let modeCode = try commandSet.parseModeResponse(response)

        // Extract filter byte if present (second data byte); FilterCode.data (0x00) = DATA mode
        let filterByte: UInt8 = response.data.count >= 2 ? response.data[1] : CIVFrame.FilterCode.fil1
        return try icomCodeToMode(modeCode, filterByte: filterByte)
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

    /// Converts a Mode enum to an Icom mode code byte (CI-V command 0x06 first data byte).
    ///
    /// Data modes (DATA-USB, DATA-LSB, DATA-FM) share their mode byte with the equivalent
    /// voice mode. The radio distinguishes them via the filter byte (0x00 = DATA, 0x01-0x03 = FIL1-3).
    /// FM-Narrow also shares the FM mode byte; filter selection controls bandwidth.
    internal func modeToIcomCode(_ mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb:     return CIVFrame.ModeCode.lsb
        case .usb:     return CIVFrame.ModeCode.usb
        case .am:      return CIVFrame.ModeCode.am
        case .cw:      return CIVFrame.ModeCode.cw
        case .cwR:     return CIVFrame.ModeCode.cwR
        case .rtty:    return CIVFrame.ModeCode.rtty
        case .rttyR:   return CIVFrame.ModeCode.rttyR
        case .fm:      return CIVFrame.ModeCode.fm
        case .fmN:     return CIVFrame.ModeCode.fm   // FM-Narrow uses same code; filter controls bandwidth
        case .wfm:     return CIVFrame.ModeCode.wfm
        case .dataLSB: return CIVFrame.ModeCode.lsb  // DATA-LSB uses LSB mode code + filter byte 0x00
        case .dataUSB: return CIVFrame.ModeCode.usb  // DATA-USB uses USB mode code + filter byte 0x00
        case .dataFM:  return CIVFrame.ModeCode.fm   // DATA-FM  uses FM  mode code + filter byte 0x00
        }
    }

    /// Returns true if the mode requires the DATA filter byte (0x00) instead of FIL1-3.
    ///
    /// On Icom radios, data modes are set by sending the base voice mode code with filter byte 0x00.
    /// This is what triggers the radio's DATA mode (separate audio path, flat response).
    internal func isDataMode(_ mode: Mode) -> Bool {
        switch mode {
        case .dataLSB, .dataUSB, .dataFM: return true
        default: return false
        }
    }

    /// Converts an Icom mode code + filter byte pair to a Mode enum.
    ///
    /// When the filter byte is `FilterCode.data` (0x00), the radio is in DATA mode
    /// for that base mode. All other filter values (0x01–0x03) indicate voice mode.
    internal func icomCodeToMode(_ code: UInt8, filterByte: UInt8 = CIVFrame.FilterCode.fil1) throws -> Mode {
        let isData = (filterByte == CIVFrame.FilterCode.data)
        switch code {
        case CIVFrame.ModeCode.lsb:
            return isData ? .dataLSB : .lsb
        case CIVFrame.ModeCode.usb:
            return isData ? .dataUSB : .usb
        case CIVFrame.ModeCode.am:
            return .am
        case CIVFrame.ModeCode.cw:
            return .cw
        case CIVFrame.ModeCode.cwR:
            return .cwR
        case CIVFrame.ModeCode.rtty:
            return .rtty
        case CIVFrame.ModeCode.rttyR:
            return .rttyR
        case CIVFrame.ModeCode.fm:
            return isData ? .dataFM : .fm
        case CIVFrame.ModeCode.wfm:
            return .wfm
        default:
            throw RigError.invalidResponse
        }
    }
}
