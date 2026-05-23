import Foundation

/// Actor implementing the Kenwood TH-D72 / TH-D72A CAT protocol.
///
/// The TH-D72 uses a CR-terminated (`\r`) command set that differs substantially
/// from the semicolon-based Kenwood CAT used by HF transceivers. Key differences:
///
/// - Frequency and mode are packed into a single `FO <vfo>` response string rather
///   than accessed via separate `FA`/`FB`/`MD` commands.
/// - VFO selection uses `BC 0` / `BC 1` rather than `FR0` / `FR1`.
/// - RF power is discrete: 0 = High (5 W), 1 = Mid (500 mW), 2 = Low (50 mW).
/// - PTT uses `TX` / `RX` (no trailing digit).
///
/// ## FO string layout (52 printable chars + CR)
/// ```
/// FO 0,0145000000,0,0,0,0,0,00,00,000,0000000,0,000000000
///    ^ ^          ^ ^ ^ ^ ^ ^  ^  ^   ^       ^ ^
///    | |          | | | | | |  |  |   |       | repeater offset (8 digits)
///    | |          | | | | | |  |  |   DCS index (3 digits)
///    | |          | | | | | |  |  CTCSS SQL index (2 digits)
///    | |          | | | | | |  CTCSS tone index (2 digits)
///    | |          | | | | | repeater shift (0=none,1=+,2=-)
///    | |          | | | | DCS on/off
///    | |          | | | CTCSS SQL on/off
///    | |          | | CTCSS tone on/off
///    | |          | tuning step index
///    | |          frequency (10 digits, Hz)
///    | VFO (0=A, 1=B)
/// ```
/// Mode is the final field: 0 = FM, 1 = FM-N, 2 = AM.
public actor THD72Protocol: CATProtocol {

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    private let responseTimeout: TimeInterval = 2.0

    /// CR terminator used by TH-series Kenwood handhelds (EOM_TH in Hamlib).
    private static let terminator: UInt8 = 0x0D  // '\r'

    /// Creates a TH-D72/TH-D72A protocol instance.
    ///
    /// - Parameters:
    ///   - transport: Serial transport (typically the radio's
    ///     virtual COM port over USB).
    ///   - capabilities: Capability set; usually
    ///     ``RadioCapabilitiesDatabase/kenwoodTHD72A``.
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        var info = try await fetchFOString(vfo: vfo)
        // Frequency occupies characters 5–14 (10 digits) in the FO string
        let freqString = String(format: "%010llu", hz)
        let chars = Array(info)
        guard chars.count >= 15 else { throw RigError.invalidResponse }
        var mutChars = chars
        for (i, c) in freqString.enumerated() {
            mutChars[5 + i] = c
        }
        info = String(mutChars)
        try await sendFOString(info)
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let info = try await fetchFOString(vfo: vfo)
        return try parseFrequency(from: info)
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let modeIndex = try modeToTHD72Index(mode)
        var info = try await fetchFOString(vfo: vfo)
        guard info.count >= 52 else { throw RigError.invalidResponse }
        var chars = Array(info)
        chars[51] = Character(String(modeIndex))
        info = String(chars)
        try await sendFOString(info)
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let info = try await fetchFOString(vfo: vfo)
        return try parseMode(from: info)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Pre-select the correct VFO bank for transmit
        try await sendCommand("BC 0")
        _ = try await receiveResponse()
        try await sendCommand(enabled ? "TX" : "RX")
        // TX/RX do not echo a response on the TH-D72
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    public func getPTT() async throws -> Bool {
        // The TH-D72 has no query command for TX state; return false conservatively.
        return false
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        let cmd: String
        switch vfo {
        case .a, .main: cmd = "BC 0"
        case .b, .sub:  cmd = "BC 1"
        }
        try await sendCommand(cmd)
        _ = try await receiveResponse()
    }

    // MARK: - Power Control

    /// Sets RF power output.
    ///
    /// The TH-D72 has three discrete power levels; `level` is
    /// interpreted as watts (PowerUnits.watts) and quantised:
    /// - High  (5 W)    — `level > 1`
    /// - Mid   (500 mW) — `level > 0` and `level ≤ 1`
    /// - Low   (50 mW)  — `level == 0`
    ///
    /// This matches the threshold logic Hamlib uses for this radio.
    public func setPower(_ level: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }
        // Threshold mapping mirrors Hamlib thd72_set_level RFPOWER:
        //   val.f <= 0.01 → step 2 (50 mW)
        //   val.f <= 0.10 → step 1 (500 mW)
        //   else          → step 0 (5 W)
        let step: Int
        if level == 0 {
            step = 2
        } else if level <= 1 {
            step = 1
        } else {
            step = 0
        }
        try await sendCommand("PC 0,\(step)")
        _ = try await receiveResponse()
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }
        try await sendCommand("PC 0")
        let response = try await receiveResponse()
        // Response: "PC 0,n" where n is 0=5W, 1=500mW, 2=50mW
        guard response.hasPrefix("PC "), response.count >= 6 else {
            throw RigError.invalidResponse
        }
        let parts = response.dropFirst(3).split(separator: ",")
        guard parts.count == 2, let level = Int(parts[1]) else {
            throw RigError.invalidResponse
        }
        switch level {
        case 0: return 5
        case 1: return 1   // report as 1W (closest integer to 500 mW)
        case 2: return 0   // report as 0W (closest integer to 50 mW)
        default: throw RigError.invalidResponse
        }
    }

    // MARK: - Split

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }
        if enabled {
            // Put both bands in VFO mode and select VFO-B as TX
            try await sendCommand("VMC 0,0")
            _ = try await receiveResponse()
            try await sendCommand("VMC 1,0")
            _ = try await receiveResponse()
            try await sendCommand("BC 1")
            _ = try await receiveResponse()
        } else {
            try await sendCommand("BC 0")
            _ = try await receiveResponse()
        }
    }

    public func getSplit() async throws -> Bool {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }
        try await sendCommand("BC")
        let response = try await receiveResponse()
        // Response: "BC n,m" — rx VFO, tx VFO; split if they differ
        guard response.hasPrefix("BC "), response.count >= 6 else {
            throw RigError.invalidResponse
        }
        let parts = response.dropFirst(3).split(separator: ",")
        guard parts.count == 2 else { throw RigError.invalidResponse }
        return parts[0] != parts[1]
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        try await sendCommand("SM 0")
        let response = try await receiveResponse()
        // Response: "SM 0,nnnn" where nnnn is 0000–0005
        guard response.hasPrefix("SM "), response.count >= 8 else {
            throw RigError.invalidResponse
        }
        let parts = response.dropFirst(3).split(separator: ",")
        guard parts.count == 2, let raw = Int(parts[1]) else {
            throw RigError.invalidResponse
        }
        // TH-D72 S-meter: 0–5 scale (coarser than HF rigs)
        // Map linearly: each unit ≈ 1.8 S-units (9 S-units / 5 steps)
        let sUnits = min(raw * 9 / 5, 9)
        return SignalStrength(sUnits: sUnits, overS9: 0, raw: raw)
    }

    // MARK: - Private: FO string helpers

    /// Fetches the packed frequency-object string for the given VFO.
    /// Command: `FO n` — response: `FO n,<52-char payload>`
    private func fetchFOString(vfo: VFO) async throws -> String {
        let vfoChar = vfoCharacter(vfo)
        try await sendCommand("FO \(vfoChar)")
        let response = try await receiveResponse()
        // Response starts with "FO n," — payload begins at index 5
        guard response.hasPrefix("FO "), response.count >= 17 else {
            throw RigError.invalidResponse
        }
        return response
    }

    /// Writes back a modified FO string to set frequency, mode, or other fields.
    /// The radio echoes the command; consume that echo.
    private func sendFOString(_ foString: String) async throws {
        try await sendCommand(foString)
        _ = try await receiveResponse()  // consume echo
    }

    /// Parses the 10-digit frequency from an FO response string.
    /// Frequency starts at character index 5 (after "FO n,").
    private func parseFrequency(from foString: String) throws -> UInt64 {
        let chars = Array(foString)
        guard chars.count >= 15 else { throw RigError.invalidResponse }
        let freqString = String(chars[5..<15])
        guard let freq = UInt64(freqString) else { throw RigError.invalidResponse }
        return freq
    }

    /// Parses the mode from the final field of an FO response string (index 51).
    /// 0 = FM, 1 = FM-N, 2 = AM
    private func parseMode(from foString: String) throws -> Mode {
        guard foString.count >= 52 else { throw RigError.invalidResponse }
        let modeChar = foString[foString.index(foString.startIndex, offsetBy: 51)]
        switch modeChar {
        case "0": return .fm
        case "1": return .fmN
        case "2": return .am
        default:  throw RigError.invalidResponse
        }
    }

    /// Maps a Mode to the TH-D72 mode index used in the FO string.
    private func modeToTHD72Index(_ mode: Mode) throws -> Int {
        switch mode {
        case .fm:  return 0
        case .fmN: return 1
        case .am:  return 2
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by TH-D72")
        }
    }

    private func vfoCharacter(_ vfo: VFO) -> String {
        switch vfo {
        case .a, .main: return "0"
        case .b, .sub:  return "1"
        }
    }

    // MARK: - Private: Transport

    private func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        data.append(THD72Protocol.terminator)
        try await transport.write(data)
    }

    private func receiveResponse() async throws -> String {
        let data = try await transport.readUntil(
            terminator: THD72Protocol.terminator,
            timeout: responseTimeout
        )
        var responseData = data
        if responseData.last == THD72Protocol.terminator {
            responseData.removeLast()
        }
        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }
        return response
    }
}
