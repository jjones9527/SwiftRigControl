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
public actor KenwoodProtocol:
    CATProtocol,
    SupportsPower,
    SupportsSplit,
    SupportsSignalStrength,
    SupportsRIT,
    SupportsXIT,
    SupportsAGC,
    SupportsNoiseBlanker,
    SupportsNoiseReduction,
    SupportsIFFilter,
    SupportsAFGain,
    SupportsRFGain,
    SupportsSquelch,
    SupportsPreamp,
    SupportsAttenuator,
    SupportsRemotePowerState,
    SupportsMemoryChannels,
    SupportsVFOOperations,
    SupportsFunctions,
    SupportsMicGain,
    SupportsCompressorLevel,
    SupportsMonitorGain,
    SupportsVOXGain,
    SupportsVOXDelay,
    SupportsIFShift
{
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Command terminator (semicolon)
    private static let terminator: UInt8 = 0x3B  // ';'

    /// How this radio selects modes, including DATA modes. See
    /// ``KenwoodModeCommandStyle``.
    public let modeStyle: KenwoodModeCommandStyle

    /// Maximum number of unrelated replies (for example unsolicited
    /// `FA` / `FB` auto-information) skipped while waiting for the
    /// `ID;` verification reply after a set command.
    static let verifyReplySkipBudget = 4

    /// Initializes a new Kenwood protocol instance.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - capabilities: The capabilities of this radio model
    ///   - modeStyle: How the radio selects modes, especially DATA
    ///     modes. Defaults to ``KenwoodModeCommandStyle/standard``,
    ///     which rejects DATA modes.
    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities,
        modeStyle: KenwoodModeCommandStyle = .standard
    ) {
        self.transport = transport
        self.capabilities = capabilities
        self.modeStyle = modeStyle
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

        try await sendSetCommand(command)
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

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // The canonical Kenwood PTT commands per Hamlib
        // `kenwood_set_ptt` (kenwood.c) are bare `TX;` (transmit)
        // and `RX;` (receive). `TX0;` and `TX1;` are *also* valid
        // but they mean "PTT via mic port" and "PTT via data port"
        // respectively — they are both *keying* commands.
        //
        // Pre-fix code sent `TX0;` for PTT-off, which is actually
        // "PTT on via mic port". On a Kenwood desktop rig, calling
        // `setPTT(false)` therefore keyed the transmitter instead
        // of releasing it. That is exactly the class of bug this
        // audit was scoped to catch.
        let command = enabled ? "TX" : "RX"
        try await sendCommand(command)

        // Kenwood radios do not echo TX/RX.
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    public func getPTT() async throws -> Bool {
        // PTT status is read from byte 28 of the `IF;` response,
        // not by re-sending `TX;` (which would key the transmitter
        // — the pre-fix code did exactly that). Matches Hamlib
        // `kenwood_get_ptt` in kenwood.c.
        //
        // The IF response is a fixed-width string; the exact
        // layout is in each radio's programmer's reference but
        // byte 28 (0-indexed) is universally the TX/RX flag
        // across the Kenwood HF line.
        try await sendCommand("IF")
        let response = try await receiveResponse()

        guard response.hasPrefix("IF"), response.count > 28 else {
            throw RigError.invalidResponse
        }

        let idx = response.index(response.startIndex, offsetBy: 28)
        return response[idx] == "1"
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

        try await sendSetCommand(command)
    }

    // MARK: - Power Control

    public func setPower(_ level: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Kenwood radios use PowerUnits.watts; `level` is interpreted as
        // watts and converted to the radio's 000–100 percentage protocol.
        let percentage = min(max((level * 100) / capabilities.maxPower, 0), 100)
        let command = String(format: "PC%03d", percentage)

        try await sendSetCommand(command)
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

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Kenwood uses SM0; for main receiver S-meter
        try await sendCommand("SM0")
        let response = try await receiveResponse()

        // Response format: "SM0nnnn" where nnnn is 0000-0030
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

        // Kenwood: Similar to Elecraft (0-30 scale)
        // 0-30 represents signal level, approximately 3 units per S-unit
        // S9 is at about 27, above that is S9+ in dB
        let sUnits = min(rawValue / 3, 9)
        let overS9 = sUnits >= 9 ? max((rawValue - 27) * 2, 0) : 0

        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        // Kenwood uses FT1 for split on, FT0 for split off
        let command = enabled ? "FT1" : "FT0"
        try await sendSetCommand(command)
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
    func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        // Add terminator (semicolon)
        data.append(KenwoodProtocol.terminator)

        try await transport.write(data)
    }

    /// Receives a response from the radio.
    func receiveResponse() async throws -> String {
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

    /// Sends a set command and confirms the radio accepted it.
    ///
    /// Kenwood set commands produce no reply, so waiting for one only
    /// times out. Like Hamlib `kenwood_transaction`
    /// (`kenwood.c:427-443`), each set is followed by `ID;`, which
    /// always answers. If the radio rejects the set command, its `?;`,
    /// `N;`, `E;` or `O;` arrives before the `ID` reply
    /// (`kenwood.c:518-600`). Unsolicited replies such as `FA` / `FB`
    /// auto-information are skipped, as Hamlib does at
    /// `kenwood.c:691-696`.
    ///
    /// - Parameter command: The set command, without the `;`
    ///   terminator.
    /// - Throws: `RigError.commandFailed` for `?;`,
    ///   `RigError.unsupportedOperation` for `N;`,
    ///   `RigError.serialPortError` for `E;`,
    ///   `RigError.invalidResponse` for `O;` or when no `ID` reply
    ///   arrives within ``verifyReplySkipBudget`` replies, and
    ///   `RigError.timeout` if the radio does not answer at all.
    func sendSetCommand(_ command: String) async throws {
        try await sendCommand(command)
        try await sendCommand("ID")

        for _ in 0..<Self.verifyReplySkipBudget {
            let reply = try await receiveResponse()
            if reply.hasPrefix("ID") {
                return
            }

            let failure: RigError
            switch reply {
            case "?":
                failure = .commandFailed("Radio rejected \(command);")
            case "N":
                failure = .unsupportedOperation("Radio does not support \(command);")
            case "E":
                failure = .serialPortError("Radio reported a communication error for \(command);")
            case "O":
                failure = .invalidResponse
            default:
                // Unsolicited auto-information; keep reading.
                continue
            }

            // The radio still answers the ID; that followed the
            // rejected command. Consume it so the next transaction
            // starts clean.
            _ = try? await receiveResponse()
            throw failure
        }

        throw RigError.invalidResponse
    }
}
