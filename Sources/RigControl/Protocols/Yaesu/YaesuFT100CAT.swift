import Foundation

/// Actor implementing the Yaesu FT-100 / FT-100D binary CAT protocol.
///
/// The FT-100 uses the same 5-byte frame shape as the FT-817 family but
/// the *legacy* parameter layout shared with the FT-1000MP: parameters
/// live in bytes 0-3, the opcode in byte 4, frequency is little-endian
/// BCD, and set commands are not acknowledged. Pre-v1.2.18 the FT-100
/// was wired to ``YaesuPortableCAT`` (FT-817 layout), so every mode and
/// PTT command put the wrong opcode on the wire.
///
/// Cross-checked against Hamlib `rigs/yaesu/ft100.c`:
///
/// ```text
/// Set freq:   [ bcd0, bcd1, bcd2, bcd3, 0x0A ]  // LE BCD, 10 Hz units (ft100.c:594-611)
/// Set mode:   [ 0x00, 0x00, 0x00, mode, 0x0C ]  // ft100.c:215-222
/// PTT on/off: [ 0x00, 0x00, 0x00, 0x01/0x00, 0x0F ]  // ft100.c:210-211
/// Select VFO: [ 0x00, 0x00, 0x00, 0x00/0x01, 0x05 ]  // ft100.c:229-230
/// Status:     [ 0x00, 0x00, 0x00, 0x00, 0x10 ] → 32 bytes (ft100.c:94-111, 259)
/// Flags:      [ 0x00, 0x00, 0x00, 0x01, 0xFA ] → 8 bytes  (ft100.c:261)
/// ```
///
/// Serial: 4800 baud only, 8-N-2, no handshake (`ft100.c:325-330`).
public actor YaesuFT100CAT: CATProtocol {

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// Time to wait for a status or flags block. At 4800 baud the
    /// 32-byte status block takes about 70 ms on the wire.
    private let responseTimeout: TimeInterval = 1.0

    /// Size of the status block returned by opcode `0x10`
    /// (`FT100_STATUS_INFO`, `ft100.c:94-111`).
    static let statusLength = 32

    /// Size of the flags block returned by opcode `0xFA`
    /// (`FT100_FLAG_INFO`, `ft100.c:128-132`).
    static let flagsLength = 8

    /// Creates an FT-100 protocol instance over the given transport.
    ///
    /// - Parameters:
    ///   - transport: Serial transport, opened at 4800 baud 8-N-2.
    ///   - capabilities: Radio capability set, normally
    ///     `RadioCapabilitiesDatabase.Yaesu.ft100`.
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    // MARK: - Frequency

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // The FT-100 has one set-frequency opcode, which targets the
        // current VFO (ft100.c:594-611); `vfo` is accepted for
        // CATProtocol conformance.
        let bcd = YaesuBinaryFrame.encodeBCDLittleEndian8(hz / 10)
        try await transport.write(Data([bcd[0], bcd[1], bcd[2], bcd[3], 0x0A]))
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let status = try await readBlock(opcodeFrame: [0x00, 0x00, 0x00, 0x00, 0x10],
                                         length: Self.statusLength)
        return Self.frequency(fromStatus: status)
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let selector = try Self.modeSelector(for: mode)
        try await transport.write(Data([0x00, 0x00, 0x00, selector, 0x0C]))
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let status = try await readBlock(opcodeFrame: [0x00, 0x00, 0x00, 0x00, 0x10],
                                         length: Self.statusLength)
        return try Self.mode(fromStatus: status)
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        try await transport.write(Data([0x00, 0x00, 0x00, enabled ? 0x01 : 0x00, 0x0F]))
    }

    public func getPTT() async throws -> Bool {
        // Flags byte 0 bit 7 = transmitting (ft100.c:953-972).
        let flags = try await readBlock(opcodeFrame: [0x00, 0x00, 0x00, 0x01, 0xFA],
                                        length: Self.flagsLength)
        return flags[flags.startIndex] & 0x80 != 0
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        let selector: UInt8 = (vfo == .b || vfo == .sub) ? 0x01 : 0x00
        try await transport.write(Data([0x00, 0x00, 0x00, selector, 0x05]))
    }

    // MARK: - Wire helpers

    /// Flushes stale input, sends a query frame and reads a
    /// fixed-length block, as Hamlib `ft100_read_status` /
    /// `ft100_read_flags` do (`ft100.c:534-592`).
    private func readBlock(opcodeFrame: [UInt8], length: Int) async throws -> Data {
        try await transport.flush()
        try await transport.write(Data(opcodeFrame))
        return try await transport.readExact(count: length, timeout: responseTimeout)
    }

    /// Decodes the status-block frequency: bytes 1-4 are a big-endian
    /// binary count in 1.25 Hz units, not BCD (`ft100.c:614-658`).
    static func frequency(fromStatus status: Data) -> UInt64 {
        let base = status.startIndex
        var raw: UInt64 = 0
        for offset in 1...4 {
            raw = (raw << 8) | UInt64(status[base + offset])
        }
        return raw * 5 / 4
    }

    /// Decodes the status-block mode: low nibble of byte 5
    /// (`ft100.c:758-800`).
    static func mode(fromStatus status: Data) throws -> Mode {
        let selector = status[status.startIndex + 5] & 0x0F
        switch selector {
        case 0x00: return .lsb
        case 0x01: return .usb
        case 0x02: return .cw
        case 0x03: return .cwR
        case 0x04: return .am
        case 0x05: return .dataUSB   // DIG
        case 0x06: return .fm
        case 0x07: return .wfm
        default: throw RigError.invalidResponse
        }
    }

    /// Maps a `Mode` to the FT-100 mode parameter byte
    /// (`ft100.c:215-222`, `ft100_set_mode` at `661-757`). DIG is the
    /// FT-100's only data mode and Hamlib maps only PKT-USB to it.
    static func modeSelector(for mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb: return 0x00
        case .usb: return 0x01
        case .cw: return 0x02
        case .cwR: return 0x03
        case .am: return 0x04
        case .dataUSB: return 0x05
        case .fm: return 0x06
        case .wfm: return 0x07
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by FT-100 CAT"
            )
        }
    }
}
