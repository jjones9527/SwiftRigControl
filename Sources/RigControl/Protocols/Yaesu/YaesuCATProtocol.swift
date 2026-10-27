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
    SupportsIFShift,
    SupportsSendCW
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
            try await sendSetCommand("SV0")
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

        // Written with no read, as Hamlib does (newcat.c:10966-10973):
        // newcat radios don't echo set commands. Pre-v1.2.19 this waited
        // for an echo that never comes.
        try await sendSetCommand(command)
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

        // Response format: FA<digits>;. Radios send
        // quirks.frequencyDigits digits (9 on modern newcat, 8 on
        // older), but the reply is parsed like Hamlib newcat_get_freq,
        // which reads every digit after the prefix (`sscanf "%lf"`),
        // so another width still decodes. Through v1.3.1 a reply of
        // any other width threw invalidResponse.
        guard response.hasPrefix(prefix) else {
            throw RigError.invalidResponse
        }
        let freqString = response.dropFirst(prefix.count)
        guard !freqString.isEmpty,
              freqString.allSatisfy({ $0.isASCII && $0.isNumber }),
              let freq = UInt64(freqString) else {
            throw RigError.invalidResponse
        }

        return freq
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        // Memory-mode escape prelude (FTX-1 quirk). See setFrequency
        // for the source citation.
        if quirks.requiresMemoryModeEscape {
            try await sendSetCommand("SV0")
        }

        guard let modeCodeChar = modeCodeTable[mode] else {
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by this Yaesu variant"
            )
        }

        // Wire format: `MD0<char>;` (VFO A) or `MD1<char>;` (VFO B).
        // Hamlib `newcat.c:1785, 1797-1800`. On radios without
        // RIG_TARGETABLE_MODE the qualifier is always `0` and the
        // `vfo` argument is ignored on the wire (front-panel
        // selection dictates which VFO the mode change lands on).
        let qualifier = modeQualifierByte(for: vfo)
        let command = "MD\(qualifier)\(modeCodeChar)"

        try await sendSetCommand(command)
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

        // Codes run `1`-`9` then `A`-`F`, so this is a character
        // lookup, not `Int(_:)` (which threw on `MD0C;` before v1.3.1).
        guard let mode = modeCodeTable.first(where: { $0.value == codeChar })?.key else {
            throw RigError.invalidResponse
        }
        return mode
    }

    /// The `MD` code table for this radio: the quirk override if there
    /// is one, otherwise ``newcatModeCodeTable``.
    private var modeCodeTable: [Mode: Character] {
        quirks.modeCodeTable ?? Self.newcatModeCodeTable
    }

    /// The newcat `MD` mode characters, copied from Hamlib
    /// `newcat_mode_conv[]` (`newcat.c:10963-10980`). Hamlib uses this
    /// one table for every newcat radio (FT-450 through FTDX101 and
    /// FT-710).
    ///
    /// Before v1.3.1 this table was numeric and had `.dataUSB` → `9`.
    /// On newcat radios `9` is RTTY-U, so DATA-USB requests (VARA HF,
    /// ARDOP) put an FT-710 into RTTY-U. DATA-U is `C`. The old table
    /// also mapped `.fmN` to `4` (FM) and had no `.rttyR` or `.dataFM`.
    public static let newcatModeCodeTable: [Mode: Character] = [
        .lsb:     "1",
        .usb:     "2",
        .cw:      "3",   // CW-U
        .fm:      "4",
        .am:      "5",
        .rtty:    "6",   // RTTY-L
        .cwR:     "7",   // CW-L
        .dataLSB: "8",   // DATA-L
        .rttyR:   "9",   // RTTY-U
        .dataFM:  "A",
        .fmN:     "B",
        .dataUSB: "C",   // DATA-U
        .amN:     "D",
        .c4fm:    "E",
        .dataFMN: "F",
    ]

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
        try await sendSetCommand(command)   // write-only, newcat.c:10966-10973

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

        try await sendSetCommand("FT\(digit)")
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
        try await sendSetCommand(command)
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
}
