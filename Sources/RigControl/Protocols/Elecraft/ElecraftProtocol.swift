import Foundation

/// Actor implementing the Elecraft text-based CAT protocol.
///
/// Elecraft radios (K2, K3, K3S, K4, KX2, KX3) use a text-based ASCII protocol
/// where commands are terminated with semicolons.
///
/// Example commands:
/// - `FA14230000;` - Set VFO A to 14.230 MHz
/// - `FA;` - Query VFO A frequency
/// - `MD2;` - Set mode to USB
/// - `TX;` - Enable PTT
public actor ElecraftProtocol: CATProtocol {
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Command terminator (semicolon + newline)
    private static let terminator: UInt8 = 0x3B  // ';'

    /// Initializes a new Elecraft protocol instance.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - capabilities: The capabilities of this radio model
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    public init(transport: any SerialTransport) {
        self.transport = transport
        self.capabilities = .full
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()

        // Send AI0; to disable auto-info mode
        try await sendCommand("AI0")
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        let command: String
        switch vfo {
        case .a, .main:
            command = String(format: "FA%011llu", hz)
        case .b, .sub:
            command = String(format: "FB%011llu", hz)
        }

        try await sendCommand(command)

        // Elecraft radios don't send ACK, they echo the command
        let response = try await receiveResponse()
        guard response.hasPrefix(command) else {
            throw RigError.commandFailed("Unexpected response: \(response)")
        }
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let command: String
        switch vfo {
        case .a, .main:
            command = "FA"
        case .b, .sub:
            command = "FB"
        }

        try await sendCommand(command)
        let response = try await receiveResponse()

        // Response format: FAxxxxxxxxxx; or FBxxxxxxxxxx;
        guard response.hasPrefix(command),
              response.count >= command.count + 11 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: command.count)
        let endIndex = response.index(startIndex, offsetBy: 11)
        let freqString = String(response[startIndex..<endIndex])

        guard let freq = UInt64(freqString) else {
            throw RigError.invalidResponse
        }

        return freq
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let modeCode = try modeToElecraftCode(mode)
        let command = "MD\(modeCode)"

        try await sendCommand(command)
        let response = try await receiveResponse()

        guard response.hasPrefix(command) else {
            throw RigError.commandFailed("Unexpected response: \(response)")
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try await sendCommand("MD")
        let response = try await receiveResponse()

        // Response format: MDx; where x is mode code
        guard response.hasPrefix("MD"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        guard let modeCode = Int(String(codeChar)) else {
            throw RigError.invalidResponse
        }

        return try elecraftCodeToMode(modeCode)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        let command = enabled ? "TX" : "RX"
        try await sendCommand(command)

        // Elecraft radios may or may not echo PTT commands
        // Just send and trust it worked
        // Small delay to ensure command is processed
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    public func getPTT() async throws -> Bool {
        // Elecraft doesn't have a direct PTT query in basic protocol
        // We can try using extended command if available
        // For now, throw unsupported
        throw RigError.unsupportedOperation("PTT query not supported on Elecraft")
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        let frCommand: String
        let ftCommand: String

        switch vfo {
        case .a, .main:
            frCommand = "FR0"  // Receive on VFO A
            ftCommand = "FT0"  // Transmit on VFO A
        case .b, .sub:
            frCommand = "FR1"  // Receive on VFO B
            ftCommand = "FT1"  // Transmit on VFO B
        }

        // Set receive VFO
        try await sendCommand(frCommand)
        let frResponse = try await receiveResponse()
        guard frResponse.hasPrefix(frCommand) else {
            throw RigError.commandFailed("VFO RX selection failed")
        }

        // Set transmit VFO
        try await sendCommand(ftCommand)
        let ftResponse = try await receiveResponse()
        guard ftResponse.hasPrefix(ftCommand) else {
            throw RigError.commandFailed("VFO TX selection failed")
        }
    }

    // MARK: - Power Control

    public func setPower(_ watts: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Convert watts to percentage (000-100)
        let percentage = min(max((watts * 100) / capabilities.maxPower, 0), 100)
        let command = String(format: "PC%03d", percentage)

        try await sendCommand(command)
        let response = try await receiveResponse()

        guard response.hasPrefix("PC") else {
            throw RigError.commandFailed("Power setting failed")
        }
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        try await sendCommand("PC")
        let response = try await receiveResponse()

        // Response format: PCxxx; where xxx is 000-100
        guard response.hasPrefix("PC"),
              response.count >= 5 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 2)
        let endIndex = response.index(startIndex, offsetBy: 3)
        let percentString = String(response[startIndex..<endIndex])

        guard let percentage = Int(percentString) else {
            throw RigError.invalidResponse
        }

        return (percentage * capabilities.maxPower) / 100
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        if enabled {
            // Split: RX on VFO A, TX on VFO B
            try await sendCommand("FR0")
            let frResponse = try await receiveResponse()
            guard frResponse.hasPrefix("FR0") else {
                throw RigError.commandFailed("Split RX VFO selection failed")
            }

            try await sendCommand("FT1")
            let ftResponse = try await receiveResponse()
            guard ftResponse.hasPrefix("FT1") else {
                throw RigError.commandFailed("Split TX VFO selection failed")
            }
        } else {
            // Normal: RX and TX on VFO A
            try await sendCommand("FR0")
            let frResponse = try await receiveResponse()
            guard frResponse.hasPrefix("FR0") else {
                throw RigError.commandFailed("Normal RX VFO selection failed")
            }

            try await sendCommand("FT0")
            let ftResponse = try await receiveResponse()
            guard ftResponse.hasPrefix("FT0") else {
                throw RigError.commandFailed("Normal TX VFO selection failed")
            }
        }
    }

    public func getSplit() async throws -> Bool {
        try await sendCommand("FT")
        let response = try await receiveResponse()

        // Response format: FTx; where x is 0 or 1
        guard response.hasPrefix("FT"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        return codeChar == "1"
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Send SM0; for main receiver (some models also support SM; for current RX)
        try await sendCommand("SM0")
        let response = try await receiveResponse()

        // Response format: "SM0nnnn" where nnnn is 0000-0030 (dB over S0)
        guard response.hasPrefix("SM0"),
              response.count >= 7 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 3)
        let endIndex = response.index(startIndex, offsetBy: 4)
        let valueString = String(response[startIndex..<endIndex])

        guard let rawValue = Int(valueString) else {
            throw RigError.invalidResponse
        }

        // Elecraft: 0-30 represents dB over S0
        // S0 to S9 = 54 dB (6 dB per S-unit)
        // So: S1 = 6 dB, S2 = 12 dB, ..., S9 = 54 dB
        let sUnits = min(rawValue / 6, 9)
        let overS9 = sUnits >= 9 ? max(rawValue - 54, 0) : 0

        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
    }

    // MARK: - Private Methods

    /// Sends a command to the radio.
    private func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        // Add terminator (semicolon)
        data.append(ElecraftProtocol.terminator)

        try await transport.write(data)
    }

    /// Receives a response from the radio.
    private func receiveResponse() async throws -> String {
        // Read until semicolon
        let data = try await transport.readUntil(
            terminator: ElecraftProtocol.terminator,
            timeout: responseTimeout
        )

        // Remove the terminator
        var responseData = data
        if responseData.last == ElecraftProtocol.terminator {
            responseData.removeLast()
        }

        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }

        return response
    }

    /// Converts a Mode enum to an Elecraft mode code.
    private func modeToElecraftCode(_ mode: Mode) throws -> Int {
        switch mode {
        case .lsb: return 1
        case .usb: return 2
        case .cw: return 3
        case .fm: return 4
        case .am: return 5
        case .dataUSB: return 6  // FSK-D (data)
        case .cwR: return 7
        case .rtty: return 8  // RTTY
        case .dataLSB: return 9  // DATA-A (data on LSB)
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Elecraft protocol")
        }
    }

    /// Converts an Elecraft mode code to a Mode enum.
    private func elecraftCodeToMode(_ code: Int) throws -> Mode {
        switch code {
        case 1: return .lsb
        case 2: return .usb
        case 3: return .cw
        case 4: return .fm
        case 5: return .am
        case 6: return .dataUSB
        case 7: return .cwR
        case 8: return .rtty
        case 9: return .dataLSB
        default:
            throw RigError.invalidResponse
        }
    }
}
