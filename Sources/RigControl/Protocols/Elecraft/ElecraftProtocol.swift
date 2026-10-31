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
///
/// ## K2-Specific Timing Requirements
/// The Elecraft K2 requires a small delay (50ms) between commands to prevent buffer overflow
/// and ensure reliable communication. This protocol automatically adds appropriate delays
/// based on the radio model, so users don't need to implement timing logic in their code.
///
/// Other Elecraft radios (K3, K3S, K4, KX series) have faster processors and larger buffers,
/// so they don't require these delays.
public actor ElecraftProtocol:
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
    SupportsAntenna,
    SupportsVFOOperations,
    SupportsFunctions
{
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses. Per-radio because the
    /// K2's slower processor can take up to 500ms to respond to
    /// band-change frequency sets — Hamlib `k2.c:139` specifies
    /// `.timeout = 2000` for exactly this reason. K3 and later
    /// run comfortably at the 1s default.
    let responseTimeout: TimeInterval

    /// Inter-command delay for K2 (nanoseconds).
    ///
    /// The K2's slower processor requires time between commands to
    /// prevent buffer overflow. Matches Hamlib `k2.c:137`
    /// `post_write_delay = 100`ms. Pre-fix value was 50ms which,
    /// under sustained rapid-fire command sequences, could cause
    /// dropped bytes on the K2's UART.
    let k2CommandDelay: UInt64 = 100_000_000  // 100ms — per Hamlib

    /// The two Elecraft command families.
    ///
    /// Hamlib drives the K2 from `rigs/kenwood/k2.c` and every later
    /// Elecraft (K3, K3S, K4, KX2, KX3) from `rigs/kenwood/k3.c`. The
    /// families differ in timing, set-command verification, the mode
    /// table and several level commands.
    public enum Family: Sendable, Equatable {
        /// The K2: 2 s timeout, 100 ms between commands, its own mode
        /// table, `FW` filter width (Hamlib `k2.c`).
        case k2
        /// K3, K3S and K4: 1 s timeout, `ID;`-verified sets, `DT` data
        /// sub-modes, `BW` filter width (Hamlib `k3.c`).
        case k3
        /// KX2 and KX3: the K3 command set, but with their own AF, RF
        /// and mic-gain scales (Hamlib `kx3_set_level` / `kx3_get_level`,
        /// `k3.c:2386-2460`).
        case kx
    }

    /// Which command family this radio uses.
    public nonisolated let family: Family

    /// How CW text goes out with `KY` (Hamlib `kenwood_send_morse`).
    public enum CWMessageForm: Sendable, Equatable {
        /// `KY <text>;`, variable length (K3, K3S, KX2, KX3); stop with
        /// `KY \u{04};` (`k3_stop_morse`, `k3.c:3053-3059`).
        case k3
        /// `KY <text padded to 24>;` (Hamlib's default form); stop with
        /// `KY @;` (`k4_stop_morse`, `k3.c:3047-3051`).
        case k4
        /// `KY <text padded to 24>;` with no stop command (K2, `k2.c:249`).
        case k2
    }

    /// CW message form; see ``CWMessageForm``.
    public nonisolated let cwMessageForm: CWMessageForm

    /// Whether this is a K2 radio (requires command delays).
    ///
    /// Through v1.3.1 this was `capabilities.maxPower <= 15`, which also
    /// matched the 12 W KX2 and 15 W KX3. They then got the K2's 2 s
    /// timeout, 100 ms command delay, unverified sets, AGC codes and
    /// `RA02` attenuator step, none of which Hamlib `k3.c` uses for them.
    var isK2: Bool { family == .k2 }

    /// Command terminator (semicolon)
    static let terminator: UInt8 = 0x3B  // ';'

    /// Initializes a new Elecraft protocol instance.
    ///
    /// ```swift
    /// let kx3 = ElecraftProtocol(
    ///     transport: transport,
    ///     capabilities: RadioCapabilitiesDatabase.Elecraft.kx3,
    ///     family: .k3
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - capabilities: The capabilities of this radio model
    ///   - family: The command family. When `nil` it is inferred from
    ///     `capabilities` with ``inferredFamily(for:)``. The
    ///     `RadioDefinition.Elecraft` factories always pass it.
    ///   - cwMessageForm: The `KY` form. When `nil`, `.k2` for the K2
    ///     family and `.k3` otherwise; the K4 factory passes `.k4`.
    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities,
        family: Family? = nil,
        cwMessageForm: CWMessageForm? = nil
    ) {
        self.transport = transport
        self.capabilities = capabilities
        self.family = family ?? Self.inferredFamily(for: capabilities)
        self.cwMessageForm = cwMessageForm ?? (self.family == .k2 ? .k2 : .k3)
        // K2 needs 2s per Hamlib k2.c:139; K3 and later, including the
        // KX2 and KX3, use 1s (k3.c:718, 877).
        self.responseTimeout = self.family == .k2 ? 2.0 : 1.0
    }

    /// Guesses the family from capabilities, for callers that don't pass
    /// one: a radio of 15 W or less without AM is the K2, one of 15 W or
    /// less with AM is a KX2 (12 W) or KX3 (15 W), anything else K3/K4.
    ///
    /// - Parameter capabilities: The radio's capabilities.
    /// - Returns: `.k2`, `.kx` or `.k3`.
    public static func inferredFamily(for capabilities: RigCapabilities) -> Family {
        guard capabilities.maxPower <= 15 else { return .k3 }
        return capabilities.supportedModes.contains(.am) ? .kx : .k2
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
        let command = enabled ? "TX" : "RX"
        try await sendCommand(command)

        // K2: SET commands don't echo, just add delay
        // Per KIO2 Pgmrs Ref: TX/RX commands only work in SSB and RTTY modes
        if isK2 {
            // K2 needs time to switch TX/RX state
            // TX transition may take longer than standard command delay
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms for TX/RX state change
        } else {
            // K3/K4: May not echo either, just delay
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    public func getPTT() async throws -> Bool {
        // K2 supports TQ (Transmit Query) command - preferred method
        // Per KIO2 Pgmrs Ref: "This is the preferred way to check RX/TX status"
        // For K3/K4, we can also use the IF command which includes TX status

        if isK2 {
            // Use TQ command for K2 (most efficient)
            // Add small delay before query to ensure TX state has stabilized
            try await Task.sleep(nanoseconds: 20_000_000) // 20ms
            return try await getTXStatus()
        } else {
            // For K3/K4, use IF command which includes TX status
            // IF response format includes 't' field: 1 if TX, 0 if RX
            try await sendCommand("IF")
            let response = try await receiveResponse()

            // IF response format: IF[f]*****+yyyyrx*00tmvspb01*;
            // Position 28 is the TX flag
            guard response.hasPrefix("IF"),
                  response.count >= 29 else {
                throw RigError.invalidResponse
            }

            let txIndex = response.index(response.startIndex, offsetBy: 28)
            return response[txIndex] == "1"
        }
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
        try await sendSetCommand(frCommand)

        // Set transmit VFO
        try await sendSetCommand(ftCommand)
    }

    // MARK: - Power Control

    public func setPower(_ level: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Every Elecraft takes `PCnnn;` in watts. K2: KIO2 Pgmrs Ref rev E
        // (000-015 QRP, 000-150 with the K2/100). K3 family: Hamlib
        // `k3_set_level` RIG_LEVEL_RFPOWER (k3.c:2023-2027). Through v1.3.1
        // the K3 family sent a percentage of maxPower, which is the same
        // number on the 100 W K3/K3S/K4 but not on the KX2 or KX3.
        let command: String
        if isK2 {
            command = String(format: "PC%03d", level)
        } else {
            command = String(format: "PC%03d", min(max(level, 0), capabilities.maxPower))
        }

        try await sendSetCommand(command)
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        try await sendCommand("PC")
        let response = try await receiveResponse()

        // Response format: PCxxx;
        guard response.hasPrefix("PC"),
              response.count >= 5 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 2)
        let endIndex = response.index(startIndex, offsetBy: 3)
        let valueString = String(response[startIndex..<endIndex])

        guard let value = Int(valueString) else {
            throw RigError.invalidResponse
        }

        // Watts on every Elecraft (k3.c:2325-2345 for the K3 family).
        return value
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        if enabled {
            // Split: RX on VFO A, TX on VFO B
            try await sendSetCommand("FR0")

            try await sendSetCommand("FT1")
        } else {
            // Normal: RX and TX on VFO A
            try await sendSetCommand("FR0")

            try await sendSetCommand("FT0")
        }
    }

    public func getSplit() async throws -> Bool {
        try await sendCommand("FT")
        let response = try await receiveResponse()

        // FT0; (TX on VFO A) or FT1; (TX on VFO B, split)
        return try Self.parseOnOffReply(response, command: "FT")
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Every Elecraft reads the main S-meter with `SM;` and answers
        // `SMnnnn;`: the K2 through `kenwood_get_level` (only the
        // TS-590/480/2000 use `SM0`), the K3 family through
        // `k3_get_level` RIG_LEVEL_STRENGTH (k3.c:2059-2080). Through
        // v1.3.1 the K3 family sent `SM0;`. Hamlib uses the higher-
        // resolution `SMH;` on K3 firmware 4.37+; not adopted here.
        let cmd = "SM"
        try await sendCommand(cmd)
        let response = try await receiveResponse()

        guard response.hasPrefix(cmd),
              response.count >= cmd.count + 4 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: cmd.count)
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
}
