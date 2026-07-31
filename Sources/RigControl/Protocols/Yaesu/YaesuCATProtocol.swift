import Foundation

/// Actor implementing the Yaesu CAT protocol for radio control.
///
/// Modern Yaesu radios (FTDX-10, FT-991A, FT-710, FT-891, etc.) use a text-based
/// CAT protocol that is compatible with Kenwood's protocol. Commands are ASCII
/// text terminated with semicolons.
///
/// Example commands:
/// - `FA14230000;` - Set VFO A to 14.230 MHz
/// - `MD2;` - Set mode to USB
/// - `TX1;` - PTT on
public actor YaesuCATProtocol:
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

    /// Per-model behavioural quirks that the shared newcat command
    /// set can't express on its own — things like whether the radio
    /// supports the `ST` split command or which numeric parameters
    /// its `FT` VFO-selection command expects.
    public let quirks: Quirks

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Command terminator (semicolon)
    private static let terminator: UInt8 = 0x3B  // ';'

    // Per-model behavioural `Quirks` struct and its presets live in
    // `YaesuCATProtocol+Quirks.swift` — extracted in v1.2.4 to keep
    // this file under the 500-line soft cap after three v1.2.x
    // wire-format audits grew it substantially.

    /// Initializes a new Yaesu CAT protocol instance.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - capabilities: The capabilities of this radio model
    ///   - quirks: Per-model quirks (defaults to `.classic` for
    ///     source-compatibility with the pre-quirks factory
    ///     signature).
    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities,
        quirks: Quirks = .classic
    ) {
        self.transport = transport
        self.capabilities = capabilities
        self.quirks = quirks
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()

        // Send AI0; to disable auto-info mode (if supported)
        try? await sendCommand("AI0")
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // Some radios (FTX-1) silently ignore FA/FB while Main is in
        // Memory mode. Force a VFO-mode restore first when the quirk
        // is set. See `Quirks.ftx1` for the source citation.
        if quirks.requiresMemoryModeEscape {
            try await sendCommand("SV0")
            _ = try await receiveResponse()
        }

        let prefix: String
        switch vfo {
        case .a, .main:
            prefix = "FA"
        case .b, .sub:
            prefix = "FB"
        }

        // Newcat frequency format is prefix + N-digit decimal Hz.
        // N is 9 for FTX-1 / FT-DX10 / FT-DX101 / FT-991A / FT-710
        // and 8 for older newcat radios (per `newcat.c` IF-response
        // length dispatch). Prior to v1.2.0 this was hard-coded to
        // 11, which no real Yaesu accepts.
        let command = "\(prefix)\(String(format: "%0\(quirks.frequencyDigits)llu", hz))"

        try await sendCommand(command)

        // Yaesu radios echo the command back
        _ = try await receiveResponse()
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let prefix: String
        switch vfo {
        case .a, .main:
            prefix = "FA"
        case .b, .sub:
            prefix = "FB"
        }

        try await sendCommand(prefix)
        let response = try await receiveResponse()

        // Response format: FA<N-digit hex>; where N = quirks.frequencyDigits
        // (9 for modern newcat, 8 for older). Prior to v1.2.0 this
        // was hard-coded to 11 — no real Yaesu response matches
        // that. See CHANGELOG for the fix.
        let digits = quirks.frequencyDigits
        guard response.hasPrefix(prefix),
              response.count >= prefix.count + digits else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: prefix.count)
        let endIndex = response.index(startIndex, offsetBy: digits)
        let freqString = String(response[startIndex..<endIndex])

        guard let freq = UInt64(freqString) else {
            throw RigError.invalidResponse
        }

        return freq
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        // Memory-mode escape prelude (FTX-1 quirk). See setFrequency
        // for the source citation.
        if quirks.requiresMemoryModeEscape {
            try await sendCommand("SV0")
            _ = try await receiveResponse()
        }

        // Radios with a custom mode-code table (FTX-1) look up the
        // character directly; older newcat radios use the shared
        // numeric table.
        let modeCodeChar: Character
        if let table = quirks.modeCodeTable {
            guard let ch = table[mode] else {
                throw RigError.unsupportedOperation(
                    "Mode \(mode.rawValue) not supported by this Yaesu variant"
                )
            }
            modeCodeChar = ch
        } else {
            let numericCode = try modeToYaesuCode(mode)
            modeCodeChar = Character("\(numericCode)")
        }

        // Wire format: `MD0<char>;` (VFO A) or `MD1<char>;` (VFO B).
        // Hamlib `newcat.c:1785, 1797-1800`. On radios without
        // RIG_TARGETABLE_MODE the qualifier is always `0` and the
        // `vfo` argument is ignored on the wire (front-panel
        // selection dictates which VFO the mode change lands on).
        let qualifier = modeQualifierByte(for: vfo)
        let command = "MD\(qualifier)\(modeCodeChar)"

        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        // Wire format: `MD0;` (VFO A) or `MD1;` (VFO B) on
        // targetable radios; `MD0;` universally otherwise. Hamlib
        // `newcat.c:1883-1885`.
        let qualifier = modeQualifierByte(for: vfo)
        try await sendCommand("MD\(qualifier)")
        let response = try await receiveResponse()

        // Response format: `MD<q><char>;` where `<q>` echoes the
        // requested VFO qualifier byte and `<char>` is the mode
        // code. Prior to the v1.2.3 fix the parser expected 3-char
        // `MD<char>;` (no qualifier) which real newcat radios
        // don't emit.
        guard response.hasPrefix("MD"),
              response.count >= 4 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 3)
        let codeChar = response[codeIndex]

        // Custom table lookup (FTX-1) — invert the character table.
        if let table = quirks.modeCodeTable {
            for (mode, ch) in table where ch == codeChar {
                return mode
            }
            throw RigError.invalidResponse
        }

        // Shared numeric table.
        guard let modeCode = Int(String(codeChar)) else {
            throw RigError.invalidResponse
        }

        return try yaesuCodeToMode(modeCode)
    }

    /// The `MD` qualifier byte for the given `vfo` per the current
    /// quirks. Returns `"0"` for VFO A / main and `"1"` for VFO B /
    /// sub, but only respects the caller's VFO argument when the
    /// radio has RIG_TARGETABLE_MODE — on non-targetable radios the
    /// qualifier is always `"0"` per Hamlib `newcat.c:1797-1800`.
    private func modeQualifierByte(for vfo: VFO) -> Character {
        guard quirks.hasTargetableMode else { return "0" }
        return (vfo == .b) ? "1" : "0"
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Yaesu uses TX0; for off, TX1; for on (different from Elecraft's TX;/RX;)
        let command = enabled ? "TX1" : "TX0"
        try await sendCommand(command)

        // Yaesu may not echo PTT commands, so just wait briefly
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    public func getPTT() async throws -> Bool {
        // Query TX status. Modern Yaesu radios (FT-950, FTDX-10,
        // FT-991A, etc.) can respond with TX0 (RX), TX1 (TX via
        // front-panel mic), TX2 (TX via rear data jack), or TX3
        // (TX via CAT/USB). Anything non-zero means the radio is
        // transmitting — matches Hamlib `newcat_get_ptt`
        // (rigs/yaesu/newcat.c:2282-2295). The pre-fix code
        // recognised only TX1 and misreported TX2/TX3 as "not
        // transmitting", which could confuse UI state and lead an
        // operator to send another PTT while the radio was already
        // keyed.
        try await sendCommand("TX")
        let response = try await receiveResponse()

        guard response.hasPrefix("TX"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        switch codeChar {
        case "0":                     return false
        case "1", "2", "3":           return true
        default:                      throw RigError.invalidResponse
        }
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        // The Yaesu newcat `FT` command has two encodings depending
        // on the radio family. On FT-950 / FT-2000 / FT-DX3000 /
        // FT-DX5000 / FT-DX1200 / FT-991(A) / FT-DX10 /
        // FT-DX101(D/MP), `FT0;` and `FT1;` *toggle* the TX
        // function, and `FT2;` / `FT3;` select VFO A / B — sending
        // `FT0;` on those radios where the operator meant "select
        // VFO A" would silently toggle TX-VFO assignment instead,
        // which is exactly the class of error the pre-fix code
        // could produce. On radios that use the classic 0/1
        // encoding (FT-710, FT-450), the offset does not apply.
        // FT-891 has no `FT` command at all per Hamlib
        // `newcat.c:516`.
        //
        // Reference: Hamlib `newcat_set_tx_vfo` (newcat.c:8164) and
        // the model-specific offset at newcat.c:8216-8222.
        guard quirks.supportsFTVFOSelection else {
            throw RigError.unsupportedOperation(
                "TX VFO selection via CAT is not supported by this Yaesu radio (FT command unavailable)"
            )
        }

        let digit: Character
        switch vfo {
        case .a, .main:
            digit = quirks.usesFT23ForVFOSelection ? "2" : "0"
        case .b, .sub:
            digit = quirks.usesFT23ForVFOSelection ? "3" : "1"
        }

        try await sendCommand("FT\(digit)")
        _ = try await receiveResponse()
    }

    // MARK: - Power Control

    public func setPower(_ level: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Yaesu radios use PowerUnits.watts; `level` is interpreted
        // as watts and converted to the radio's 000–100 percentage protocol.
        let percentage = min(max((level * 100) / capabilities.maxPower, 0), 100)
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

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Yaesu FT-991A and similar use RM5; to read main S-meter
        // Note: Command may vary by model (RM1-RM9 for different meters)
        try await sendCommand("RM5")
        let response = try await receiveResponse()

        // Response format: "RM5nnn" where nnn is 000-255
        guard response.hasPrefix("RM5"),
              response.count >= 6 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 3)
        let endIndex = response.index(startIndex, offsetBy: 3)
        let valueString = String(response[startIndex..<endIndex])

        guard let rawValue = Int(valueString) else {
            throw RigError.invalidResponse
        }

        // Yaesu: 0-255 scale
        // Roughly: 0-120 = S0-S9 (about 13 units per S-unit)
        // 121-255 = S9+1 to S9+60 (about 2 units per dB)
        let sUnits = min(rawValue / 13, 9)
        let overS9 = sUnits >= 9 ? max((rawValue - 117) / 2, 0) : 0

        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
    }

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// Per Hamlib `rigs/yaesu/newcat.c` `newcat_set_rit`:
    /// - `RC;` (clarifier-clear) prelude — clears any accumulated
    ///   offset so the new value is absolute, not relative.
    /// - `RUnnnn;` (positive offset) or `RDnnnn;` (negative offset) —
    ///   4-digit **unsigned** decimal, direction encoded in the
    ///   command letter (`RU` = up / positive, `RD` = down /
    ///   negative). Hamlib uses `%04ld` with `labs()`.
    /// - `RT1;` to enable, `RT0;` to disable.
    ///
    /// Prior to the v1.2.0 audit fix Swift emitted signed 5-digit
    /// values (`RU+0100;`) which real newcat radios reject — the
    /// `+` sign character is not part of the on-wire format.
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled
    ///   and offset in Hz, -9999 to +9999)
    /// - Throws: `RigError` if operation fails
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Clear any accumulated offset before setting a new one.
        try await sendCommand("RC")
        _ = try await receiveResponse()

        // Direction encoded in command letter; value is unsigned.
        let magnitude = abs(state.offset)
        let command: String
        if state.offset >= 0 {
            command = String(format: "RU%04d", magnitude)
        } else {
            command = String(format: "RD%04d", magnitude)
        }

        try await sendCommand(command)
        _ = try await receiveResponse()

        // Set RIT ON/OFF
        let enableCommand = state.enabled ? "RT1" : "RT0"
        try await sendCommand(enableCommand)
        _ = try await receiveResponse()
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset.
    ///
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails
    public func getRIT() async throws -> RITXITState {
        // Read RIT ON/OFF status
        try await sendCommand("RT")
        let enableResponse = try await receiveResponse()

        // Response format: RTx; where x is 0 or 1
        guard enableResponse.hasPrefix("RT"),
              enableResponse.count >= 3 else {
            throw RigError.invalidResponse
        }

        let enableIndex = enableResponse.index(enableResponse.startIndex, offsetBy: 2)
        let enableChar = enableResponse[enableIndex]
        let enabled = enableChar == "1"

        // Read RIT offset
        // Note: Some Yaesu radios may not support reading offset directly
        // In that case, we return 0 as offset
        var offset = 0
        do {
            try await sendCommand("RC")
            let offsetResponse = try await receiveResponse()

            // Response format: RC+nnnnn; or RC-nnnnn;
            guard offsetResponse.hasPrefix("RC"),
                  offsetResponse.count >= 8 else {
                throw RigError.invalidResponse
            }

            let startIndex = offsetResponse.index(offsetResponse.startIndex, offsetBy: 2)
            let endIndex = offsetResponse.index(startIndex, offsetBy: 6)
            let offsetString = String(offsetResponse[startIndex..<endIndex])

            offset = Int(offsetString) ?? 0
        } catch {
            // If RC command not supported, default to 0 offset
            offset = 0
        }

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// Yaesu radios using Kenwood-compatible CAT commands use:
    /// - `XT1;` to enable XIT
    /// - `XT0;` to disable XIT
    /// - Offset is typically shared with RIT
    ///
    /// **Note:** Many Yaesu radios don't support separate XIT control.
    /// They use RIT for both receive and transmit offset.
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or unsupported
    public func setXIT(_ state: RITXITState) async throws {
        // Try to set XIT - many radios don't support this
        let enableCommand = state.enabled ? "XT1" : "XT0"

        do {
            try await sendCommand(enableCommand)
            _ = try await receiveResponse()
        } catch {
            // If XIT command not supported, throw unsupported error
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio - use RIT instead")
        }
    }

    /// Gets the current XIT state.
    ///
    /// **Note:** Many Yaesu radios don't support separate XIT control.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if XIT not supported
    public func getXIT() async throws -> RITXITState {
        // Try to read XIT status
        do {
            try await sendCommand("XT")
            let response = try await receiveResponse()

            // Response format: XTx; where x is 0 or 1
            guard response.hasPrefix("XT"),
                  response.count >= 3 else {
                throw RigError.invalidResponse
            }

            let enableIndex = response.index(response.startIndex, offsetBy: 2)
            let enableChar = response[enableIndex]
            let enabled = enableChar == "1"

            // XIT typically shares offset with RIT on Yaesu radios
            return RITXITState(enabled: enabled, offset: 0)
        } catch {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        // Yaesu's canonical split command is `ST0;` (off) / `ST1;`
        // (on), *not* `FT0;`/`FT1;` — the pre-fix code used `FT`,
        // which is TX-VFO selection. On FT-950/FT-2000/FT-991(A)/
        // FT-DX3000/5000/1200/9000, sending `FT1;` where split was
        // intended would silently reassign the TX VFO instead of
        // enabling split, and could TX on the wrong frequency.
        //
        // Reference: Hamlib `newcat_set_split` (newcat.c:8317).
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        guard quirks.supportsSTSplit else {
            // On radios without `ST` (FT-950/891/991/2000/DX3000
            // etc.), Hamlib establishes split by explicitly
            // selecting the TX VFO via `FT`. That is a semantically
            // different operation (which VFO transmits, rather
            // than an on/off toggle), so surface it explicitly
            // rather than silently doing the wrong thing.
            throw RigError.unsupportedOperation(
                "Split cannot be toggled as a state on this Yaesu radio; use selectVFO() to set the TX VFO explicitly"
            )
        }

        let command = enabled ? "ST1" : "ST0"
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    public func getSplit() async throws -> Bool {
        guard quirks.supportsSTSplit else {
            throw RigError.unsupportedOperation(
                "Split state cannot be read on this Yaesu radio (ST command unavailable)"
            )
        }

        try await sendCommand("ST")
        let response = try await receiveResponse()

        // Response format: STx; where x is 0 (off) or 1 (on)
        guard response.hasPrefix("ST"),
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
        data.append(YaesuCATProtocol.terminator)

        try await transport.write(data)
    }

    /// Receives a response from the radio.
    func receiveResponse() async throws -> String {
        // Read until semicolon
        let data = try await transport.readUntil(
            terminator: YaesuCATProtocol.terminator,
            timeout: responseTimeout
        )

        // Remove the terminator
        var responseData = data
        if responseData.last == YaesuCATProtocol.terminator {
            responseData.removeLast()
        }

        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }

        return response
    }

    /// Converts a Mode enum to a Yaesu mode code.
    private func modeToYaesuCode(_ mode: Mode) throws -> Int {
        switch mode {
        case .lsb: return 1
        case .usb: return 2
        case .cw: return 3
        case .fm: return 4
        case .am: return 5
        case .rtty: return 6  // FSK
        case .cwR: return 7
        case .dataLSB: return 8  // PKT-LSB
        case .dataUSB: return 9  // PKT-USB (or DATA-USB)
        case .fmN: return 4  // FM (Yaesu doesn't distinguish FM/FM-N in mode code)
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Yaesu protocol")
        }
    }

    /// Converts a Yaesu mode code to a Mode enum.
    private func yaesuCodeToMode(_ code: Int) throws -> Mode {
        switch code {
        case 1: return .lsb
        case 2: return .usb
        case 3: return .cw
        case 4: return .fm
        case 5: return .am
        case 6: return .rtty
        case 7: return .cwR
        case 8: return .dataLSB
        case 9: return .dataUSB
        default:
            throw RigError.invalidResponse
        }
    }
}
