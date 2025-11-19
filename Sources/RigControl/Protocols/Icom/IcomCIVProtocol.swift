import Foundation

/// Actor implementing the Icom CI-V protocol for radio control.
///
/// The CI-V (Computer Interface V) protocol is used by Icom transceivers for CAT control.
/// This implementation supports frequency, mode, PTT, VFO, and power control operations.
public actor IcomCIVProtocol: CATProtocol {
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The CI-V address of the radio
    private let civAddress: UInt8

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Initializes a new Icom CI-V protocol instance.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - civAddress: The CI-V address of the radio (e.g., 0xA2 for IC-9700)
    ///   - capabilities: The capabilities of this radio model
    public init(transport: any SerialTransport, civAddress: UInt8, capabilities: RigCapabilities) {
        self.transport = transport
        self.civAddress = civAddress
        self.capabilities = capabilities
    }

    /// Required initializer from CATProtocol (throws since we need civAddress)
    public init(transport: any SerialTransport) {
        fatalError("Use init(transport:civAddress:capabilities:) for Icom radios")
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
        // Select the appropriate VFO first
        try await selectVFO(vfo)

        // Encode frequency in BCD
        let freqData = BCDEncoding.encodeFrequency(hz)

        // Build and send command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.setFrequency],
            data: freqData
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected frequency \(hz) Hz")
        }
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        // Select the appropriate VFO first
        try await selectVFO(vfo)

        // Build and send query command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readFrequency]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Response should contain frequency data
        guard response.command[0] == CIVFrame.Command.readFrequency,
              response.data.count == 5 else {
            throw RigError.invalidResponse
        }

        return try BCDEncoding.decodeFrequency(response.data)
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        // Select the appropriate VFO first
        try await selectVFO(vfo)

        // Convert Mode enum to Icom mode code
        let modeCode = try modeToIcomCode(mode)

        // Build and send command
        // Data format: [mode, filter] - filter 0x00 for default
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.setMode],
            data: [modeCode, 0x00]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected mode \(mode)")
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        // Select the appropriate VFO first
        try await selectVFO(vfo)

        // Build and send query command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readMode]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Response should contain mode data
        guard response.command[0] == CIVFrame.Command.readMode,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }

        let modeCode = response.data[0]
        return try icomCodeToMode(modeCode)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Build and send command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ptt],
            data: [enabled ? 0x01 : 0x00]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected PTT \(enabled ? "on" : "off")")
        }
    }

    public func getPTT() async throws -> Bool {
        // Build and send query command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ptt]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.command[0] == CIVFrame.Command.ptt,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }

        return response.data[0] == 0x01
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

    public func setPower(_ watts: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Convert watts to percentage (0-255)
        let percentage = min(max((watts * 255) / capabilities.maxPower, 0), 255)
        let powerData = BCDEncoding.encodePower(percentage)

        // Build and send command
        // Command 0x14, sub-command 0x0A for RF power
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, 0x0A],
            data: powerData
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

        // Build and send query command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, 0x0A]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.settings,
              response.command[1] == 0x0A,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }

        let percentage = BCDEncoding.decodePower(response.data)
        return (percentage * capabilities.maxPower) / 255
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

    // MARK: - Private Methods

    /// Sends a CI-V frame to the radio.
    private func sendFrame(_ frame: CIVFrame) async throws {
        let data = Data(frame.bytes())
        try await transport.write(data)
    }

    /// Receives a CI-V frame from the radio.
    private func receiveFrame() async throws -> CIVFrame {
        // Read until terminator (0xFD)
        let data = try await transport.readUntil(
            terminator: CIVFrame.terminator,
            timeout: responseTimeout
        )

        return try CIVFrame.parse(data)
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
}
