import Foundation

/// Actor implementing the Kenwood CAT protocol for radio control.
///
/// Kenwood radios use a text-based CAT protocol with ASCII commands terminated
/// by semicolons. This protocol is also used by Yaesu modern radios and some
/// other manufacturers (it's a de facto standard).
///
/// Example commands:
/// - `FA14230000;` - Set VFO A to 14.230 MHz
/// - `MD2;` - Set mode to USB
/// - `TX1;` - PTT on
public actor KenwoodProtocol: CATProtocol {
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Command terminator (semicolon)
    private static let terminator: UInt8 = 0x3B  // ';'

    /// Initializes a new Kenwood protocol instance.
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
        try? await sendCommand("AI0")
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

        // Kenwood radios echo the command back
        _ = try await receiveResponse()
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
        let modeCode = try modeToKenwoodCode(mode)
        let command = "MD\(modeCode)"

        try await sendCommand(command)
        _ = try await receiveResponse()
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

        return try kenwoodCodeToMode(modeCode)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Kenwood uses TX1; for on, TX0; for off
        let command = enabled ? "TX1" : "TX0"
        try await sendCommand(command)

        // Some Kenwood radios may not echo PTT commands
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    public func getPTT() async throws -> Bool {
        // Try reading TX status
        try await sendCommand("TX")
        let response = try await receiveResponse()

        // Response format: TXx; where x is 0 or 1
        guard response.hasPrefix("TX"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        return codeChar == "1"
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        let command: String
        switch vfo {
        case .a, .main:
            command = "FR0"  // Select VFO A for receive
        case .b, .sub:
            command = "FR1"  // Select VFO B for receive
        }

        try await sendCommand(command)
        _ = try await receiveResponse()
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
        _ = try await receiveResponse()
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

        // Kenwood uses FT1 for split on, FT0 for split off
        let command = enabled ? "FT1" : "FT0"
        try await sendCommand(command)
        _ = try await receiveResponse()
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

    // MARK: - Private Methods

    /// Sends a command to the radio.
    private func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        // Add terminator (semicolon)
        data.append(KenwoodProtocol.terminator)

        try await transport.write(data)
    }

    /// Receives a response from the radio.
    private func receiveResponse() async throws -> String {
        // Read until semicolon
        let data = try await transport.readUntil(
            terminator: KenwoodProtocol.terminator,
            timeout: responseTimeout
        )

        // Remove the terminator
        var responseData = data
        if responseData.last == KenwoodProtocol.terminator {
            responseData.removeLast()
        }

        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }

        return response
    }

    /// Converts a Mode enum to a Kenwood mode code.
    private func modeToKenwoodCode(_ mode: Mode) throws -> Int {
        switch mode {
        case .lsb: return 1
        case .usb: return 2
        case .cw: return 3
        case .fm: return 4
        case .am: return 5
        case .rtty: return 6  // FSK
        case .cwR: return 7
        case .dataLSB: return 9  // DATA modes on Kenwood
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Kenwood protocol")
        }
    }

    /// Converts a Kenwood mode code to a Mode enum.
    private func kenwoodCodeToMode(_ code: Int) throws -> Mode {
        switch code {
        case 1: return .lsb
        case 2: return .usb
        case 3: return .cw
        case 4: return .fm
        case 5: return .am
        case 6: return .rtty
        case 7: return .cwR
        case 9: return .dataLSB
        default:
            throw RigError.invalidResponse
        }
    }
}
