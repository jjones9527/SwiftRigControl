import Foundation

/// CAT protocol implementation for Ten-Tec Orion-family radios (TT-565, TT-599, Eagle).
///
/// The Orion protocol uses a hybrid ASCII/binary framing:
/// - **Set commands** start with `*` followed by the command code and binary payload, terminated with CR
/// - **Query commands** start with `?` followed by the command code, terminated with CR
/// - **Responses** start with `@` followed by the data, terminated with CR
/// - **Errors** are indicated by `Z!` prefix
///
/// ## Frequency Encoding
/// Frequency is encoded as 4 bytes big-endian (Hz), preceded by the VFO selector (`A` or `B`):
/// ```
/// Set:   * A <B3> <B2> <B1> <B0> \r   (VFO A)
/// Query: ? A \r
/// Response: @ A <B3> <B2> <B1> <B0> \r
/// ```
///
/// ## Mode Codes
/// ```
/// U = USB   L = LSB   C = CW   R = CW-Reverse   A = AM   F = FM   T = RTTY
/// ```
///
/// ## PTT
/// ```
/// *TK\r = TX on    *TU\r = TX off
/// ```
///
/// Reference: Hamlib `rigs/tentec/orion.c`
public actor TenTecOrionProtocol:
    CATProtocol,
    SupportsSplit,
    SupportsSignalStrength
{
    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// The radio model (determines dual-receiver capability)
    private let radioModel: TenTecModel

    /// Command terminator (CR)
    private static let cr: UInt8 = 0x0D

    /// Response start marker
    private static let responseMarker: UInt8 = 0x40  // '@'

    /// Response timeout
    private let responseTimeout: TimeInterval = 2.0

    /// Creates an Orion-family protocol instance.
    ///
    /// - Parameters:
    ///   - transport: Serial transport to communicate over.
    ///   - radioModel: Specific Orion-family model (Orion, Orion II, Eagle).
    ///   - capabilities: Capability set for the chosen model.
    public init(transport: any SerialTransport, radioModel: TenTecModel, capabilities: RigCapabilities) {
        self.transport = transport
        self.radioModel = radioModel
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
        let vfoChar: UInt8 = vfoSelector(vfo)
        // 4 bytes big-endian, clamped to UInt32 range (all HF freqs fit easily)
        let freq = UInt32(min(hz, UInt64(UInt32.max)))
        let bytes: [UInt8] = [
            0x2A,              // '*'
            vfoChar,
            UInt8((freq >> 24) & 0xFF),
            UInt8((freq >> 16) & 0xFF),
            UInt8((freq >> 8) & 0xFF),
            UInt8(freq & 0xFF),
            Self.cr
        ]
        try await transport.write(Data(bytes))
        // Orion does not send an ACK for set commands — no response to read
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let vfoChar: UInt8 = vfoSelector(vfo)
        try await sendQuery([0x3F, vfoChar])  // '?' + VFO

        let response = try await readResponse()
        // Response: @ <vfoChar> <B3> <B2> <B1> <B0> \r  (at least 6 data bytes after '@')
        guard response.count >= 6, response[0] == vfoChar else {
            throw RigError.invalidResponse
        }
        let freq = UInt64(response[1]) << 24
                 | UInt64(response[2]) << 16
                 | UInt64(response[3]) << 8
                 | UInt64(response[4])
        return freq
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let receiver: UInt8 = receiverSelector(vfo)
        guard let modeChar = orionModeCode(mode) else {
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Ten-Tec Orion")
        }
        // *R<M|S>M<mode>\r
        try await sendSet([0x52, receiver, 0x4D, modeChar])  // 'R', receiver, 'M', modeChar
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let receiver: UInt8 = receiverSelector(vfo)
        // ?R<M|S>M\r
        try await sendQuery([0x52, receiver, 0x4D])

        let response = try await readResponse()
        // Response: @ R<M|S>M<modeChar>\r  — payload after '@' is R, receiver, M, modeChar
        guard response.count >= 4,
              response[0] == 0x52,   // 'R'
              response[2] == 0x4D    // 'M'
        else {
            throw RigError.invalidResponse
        }
        return try orionCodeToMode(response[3])
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // *TK\r = TX on, *TU\r = TX off
        let keyChar: UInt8 = enabled ? 0x4B : 0x55  // 'K' or 'U'
        try await sendSet([0x54, keyChar])  // 'T', keyChar
    }

    public func getPTT() async throws -> Bool {
        try await sendQuery([0x54])  // 'T'
        let response = try await readResponse()
        guard response.count >= 2, response[0] == 0x54 else {
            throw RigError.invalidResponse
        }
        return response[1] == 0x4B  // 'K' = keyed (TX)
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        // Orion doesn't have a standalone VFO select command — VFO is embedded in each command
    }

    // MARK: - Split

    public func setSplit(_ enabled: Bool) async throws {
        // *ES\r = split on, *EX\r = split off (S=Sub, X=off — toggle sub receiver routing)
        let code: UInt8 = enabled ? 0x53 : 0x58  // 'S' or 'X'
        try await sendSet([0x45, code])  // 'E', code
    }

    public func getSplit() async throws -> Bool {
        try await sendQuery([0x45])
        let response = try await readResponse()
        guard response.count >= 2, response[0] == 0x45 else {
            throw RigError.invalidResponse
        }
        return response[1] == 0x53  // 'S' = split on
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // ?S\r — query S-meter on main receiver
        try await sendQuery([0x53])  // 'S'
        let response = try await readResponse()
        guard response.count >= 2, response[0] == 0x53 else {
            throw RigError.invalidResponse
        }
        // Response byte is 0–160: 0–120 = S0–S9 (roughly 13.3 units/S-unit), 121–160 = S9+dB
        let raw = Int(response[1])
        let sUnits: Int
        let overS9: Int
        if raw <= 120 {
            sUnits = min(raw / 14, 9)
            overS9 = 0
        } else {
            sUnits = 9
            overS9 = min((raw - 120) / 2, 60)
        }
        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: raw)
    }

    // MARK: - Private Helpers

    /// Send a set command: `*` + payload + CR
    private func sendSet(_ payload: [UInt8]) async throws {
        var bytes: [UInt8] = [0x2A]  // '*'
        bytes.append(contentsOf: payload)
        bytes.append(Self.cr)
        try await transport.write(Data(bytes))
    }

    /// Send a query command: `?` + payload + CR
    private func sendQuery(_ payload: [UInt8]) async throws {
        var bytes: [UInt8] = [0x3F]  // '?'
        bytes.append(contentsOf: payload)
        bytes.append(Self.cr)
        try await transport.write(Data(bytes))
    }

    /// Read a response terminated by CR. Strips the leading `@` marker and the trailing CR.
    private func readResponse() async throws -> [UInt8] {
        let data = try await transport.readUntil(terminator: Self.cr, timeout: responseTimeout)
        var bytes = [UInt8](data)

        // Drop trailing CR if present
        if bytes.last == Self.cr { bytes.removeLast() }

        // Must start with '@'
        guard bytes.first == Self.responseMarker else {
            throw RigError.invalidResponse
        }
        return Array(bytes.dropFirst())  // payload after '@'
    }

    /// Maps a VFO to the Orion VFO byte ('A'=0x41, 'B'=0x42)
    private func vfoSelector(_ vfo: VFO) -> UInt8 {
        switch vfo {
        case .a, .main: return 0x41  // 'A'
        case .b, .sub:  return 0x42  // 'B'
        }
    }

    /// Maps a VFO to the Orion receiver byte ('M'=main=0x4D, 'S'=sub=0x53)
    private func receiverSelector(_ vfo: VFO) -> UInt8 {
        switch vfo {
        case .a, .main: return 0x4D  // 'M'
        case .b, .sub:  return 0x53  // 'S'
        }
    }

    /// Maps a Mode to the Orion single-character mode code
    private func orionModeCode(_ mode: Mode) -> UInt8? {
        switch mode {
        case .usb:              return 0x55  // 'U'
        case .lsb:              return 0x4C  // 'L'
        case .cw:               return 0x43  // 'C'
        case .cwR:              return 0x52  // 'R'
        case .am:               return 0x41  // 'A'
        case .fm:               return 0x46  // 'F'
        case .rtty:             return 0x54  // 'T'
        case .dataUSB, .dataLSB, .dataFM, .fmN, .rttyR, .wfm:
            return nil
        }
    }

    /// Maps an Orion mode byte to a Mode enum
    private func orionCodeToMode(_ code: UInt8) throws -> Mode {
        switch code {
        case 0x55: return .usb   // 'U'
        case 0x4C: return .lsb   // 'L'
        case 0x43: return .cw    // 'C'
        case 0x52: return .cwR   // 'R'
        case 0x41: return .am    // 'A'
        case 0x46: return .fm    // 'F'
        case 0x54: return .rtty  // 'T'
        default:   throw RigError.invalidResponse
        }
    }
}
