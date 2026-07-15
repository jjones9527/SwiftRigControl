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

    /// Per-model behavioural quirks.
    ///
    /// The Yaesu newcat command family is *mostly* uniform across
    /// modern HF radios, but the `ST` (split) and `FT` (TX VFO
    /// selection) commands diverge across models. This struct
    /// captures the differences without leaking Yaesu-specifics
    /// into the shared `RigCapabilities` type.
    ///
    /// Sourced from Hamlib `rigs/yaesu/newcat.c` — the
    /// `valid_commands` table (which model supports which command)
    /// and the model-specific branches inside `newcat_set_split_vfo`
    /// / `newcat_set_tx_vfo`.
    public struct Quirks: Sendable {
        /// `true` when the radio supports the `ST0;` / `ST1;` split
        /// command. FTDX-10, FT-DX101(D/MP), FT-710, FT-450 — but
        /// FT-450's `ST` means Step, not Split, so Hamlib excludes
        /// it there. See `newcat.c:578` and the exclusion at
        /// `newcat.c:8327`.
        public let supportsSTSplit: Bool

        /// `true` when the radio's `FT` command uses the `FT2;` /
        /// `FT3;` numeric encoding for VFO A/B (with `FT0;`/`FT1;`
        /// reserved for toggling the TX function). Applies to
        /// FT-950, FT-2000, FT-DX3000/5000/1200, FT-991(A),
        /// FTDX-10, FT-DX101(D/MP). Other radios use the classic
        /// `FT0;`/`FT1;` for A/B. See `newcat.c:8216-8222`.
        public let usesFT23ForVFOSelection: Bool

        /// `true` when the radio's `FT` command exists at all. The
        /// FT-891 is the only known modern Yaesu HF radio that has
        /// no `FT` command per `newcat.c:516`. Without `FT`, split
        /// operation cannot be established via the newcat protocol.
        public let supportsFTVFOSelection: Bool

        public init(
            supportsSTSplit: Bool = false,
            usesFT23ForVFOSelection: Bool = false,
            supportsFTVFOSelection: Bool = true
        ) {
            self.supportsSTSplit = supportsSTSplit
            self.usesFT23ForVFOSelection = usesFT23ForVFOSelection
            self.supportsFTVFOSelection = supportsFTVFOSelection
        }

        /// Portable / mobile radios (FT-817/818/857/897/847/920/100/
        /// 1000MP): pre-newcat binary CAT — this shared newcat
        /// implementation does not drive them anyway, but for the
        /// factories that reference this struct we default to the
        /// classic (non-newcat) semantics.
        public static let classic = Quirks()

        /// FT-950, FT-2000, FT-DX3000/5000/1200, FT-991, FT-991A —
        /// no `ST` command, `FT` uses 2/3 for VFO A/B. Split is not
        /// a first-class state on these radios; operators drive
        /// split by explicitly selecting TX VFO.
        public static let newcatNoST = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true
        )

        /// FT-DX10, FT-DX101D, FT-DX101MP, FT-710 — full `ST`
        /// support. `FT` still uses 2/3 for VFO selection on
        /// FT-DX10/101(D/MP) per `newcat.c:8216-8218`; FT-710 uses
        /// classic 0/1.
        public static let newcatWithSTDX = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true
        )

        /// FT-710 — supports `ST` split and uses classic `FT0;`/
        /// `FT1;` for VFO A/B selection.
        public static let ft710 = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: false,
            supportsFTVFOSelection: true
        )

        /// FT-450 / FT-450D — `ST` means Step, not Split, on this
        /// radio. Hamlib explicitly disables split via `ST`
        /// (`newcat.c:8327`). Fall back to `FT` for VFO selection.
        public static let ft450 = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: false,
            supportsFTVFOSelection: true
        )

        /// FT-891 — no `FT` command per `newcat.c:516`. Split via
        /// newcat is not available on this radio; both split and
        /// TX VFO selection must throw `unsupportedOperation`.
        public static let ft891 = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: false,
            supportsFTVFOSelection: false
        )
    }

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
        let command: String
        switch vfo {
        case .a, .main:
            command = String(format: "FA%011llu", hz)
        case .b, .sub:
            command = String(format: "FB%011llu", hz)
        }

        try await sendCommand(command)

        // Yaesu radios echo the command back
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
        let modeCode = try modeToYaesuCode(mode)
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

        return try yaesuCodeToMode(modeCode)
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
    /// Yaesu radios using Kenwood-compatible CAT commands use:
    /// - `RT1;` to enable RIT
    /// - `RT0;` to disable RIT
    /// - `RU+nnnn;` or `RD+nnnn;` to set offset (in Hz, -9999 to +9999)
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Set RIT offset using RU (up) or RD (down) command
        // Format: RU+nnnn; or RD-nnnn; (signed offset value)
        let command: String
        if state.offset >= 0 {
            command = String(format: "RU%+05d", state.offset)
        } else {
            command = String(format: "RD%+05d", state.offset)
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
