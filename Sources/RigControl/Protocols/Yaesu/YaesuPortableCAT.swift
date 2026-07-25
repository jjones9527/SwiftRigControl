import Foundation

/// Actor implementing the pre-newcat Yaesu binary CAT protocol used
/// by the FT-817 family of portable/mobile radios.
///
/// This is the "5-byte fixed frame" CAT that Yaesu shipped with the
/// FT-817 (2000) and reused for the FT-818, FT-857, FT-857D, FT-897,
/// FT-897D, FT-100, and FT-920. It has **nothing in common** with the
/// semicolon-terminated `newcat` CAT used by the FT-950 / FT-991 /
/// FTdx / FT-710 line — those live in ``YaesuCATProtocol``. Trying
/// to drive an FT-817-family radio with newcat commands returns
/// silence.
///
/// ## Frame layout
///
/// Every command is exactly 5 bytes:
///
/// ```text
/// [ P1, P2, P3, P4, Opcode ]
/// ```
///
/// - The opcode identifies the command.
/// - P1-P4 hold parameters (frequency BCD, mode selector, etc.), or
///   zero for opcode-only commands.
/// - No checksum, no terminator, no framing bytes.
///
/// ## Wire semantics
///
/// - **Set commands** (frequency, mode, PTT): the radio replies with
///   a single ACK byte after the 5-byte command. `0x00` = OK. Cross-
///   checked against Hamlib `rigs/yaesu/ft817.c` `ft817_read_ack()`
///   (line ~1424).
/// - **Status commands** (`get freq+mode` = opcode `0x03`,
///   `get TX status` = opcode `0xF7`): the radio replies with a
///   multi-byte payload without an ACK. Frame layout below.
///
/// ## Set frequency (opcode 0x01)
///
/// ```text
/// bytes 0-3: frequency in 10-Hz units, packed as 8-digit big-endian BCD
/// byte 4:    0x01
/// ```
///
/// The FT-817 truncates to 10 Hz. Cross-checked against Hamlib
/// `ft817_set_freq()` (line ~1501) — `to_bcd_be(data, freq/10, 8)`.
///
/// ## Get frequency + mode (opcode 0x03)
///
/// Send `[0,0,0,0,0x03]`. The radio replies with 5 bytes:
///
/// ```text
/// bytes 0-3: current frequency, 10-Hz units, 8-digit big-endian BCD
/// byte 4:    mode selector; bit 7 = narrow flag, bits 0-6 = mode
/// ```
///
/// Cross-checked against Hamlib `ft817_get_freq()` (line ~891) —
/// `from_bcd_be(p->fm_status, 8)`.
///
/// ## PTT
///
/// - Set PTT on: `[0,0,0,0,0x08]`, ACK-terminated.
/// - Set PTT off: `[0,0,0,0,0x88]`, ACK-terminated.
/// - Get PTT state: send `[0,0,0,0,0xF7]`. Radio replies with 1 byte;
///   `0xFF` = no TX, anything else = transmitting. Cross-checked
///   against Hamlib `ft817_get_ptt()` — `*ptt = tx_status != 0xff`.
///
/// ## Mode set (opcode 0x07)
///
/// Send `[modeSelector, 0, 0, 0, 0x07]`. Selectors are:
///
/// | Mode      | Selector |
/// | --------- | -------- |
/// | LSB       | 0x00     |
/// | USB       | 0x01     |
/// | CW        | 0x02     |
/// | CW-R      | 0x03     |
/// | AM        | 0x04     |
/// | FM        | 0x08     |
/// | FM-N      | 0x88     |
/// | DIG       | 0x0A     |
/// | PKT       | 0x0C     |
///
/// Cross-checked against Hamlib `rigs/yaesu/ft817.c` command table
/// (lines 183-192).
///
/// ## VFO selection (opcode 0x81)
///
/// The FT-817 family has a single toggle command: `[0,0,0,0,0x81]`
/// flips A ↔ B. There is no direct "select A" or "select B" — the
/// operator has to read the current state and toggle if needed. For
/// the current release we implement `selectVFO(_:)` as a no-op that
/// returns silently; the operator drives VFO switching from the
/// front panel.
public actor YaesuPortableCAT:
    CATProtocol,
    SupportsSignalStrength
{

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// How long to wait for the ACK byte after a set command, or the
    /// status payload after a get command. Hamlib default retry is
    /// small; 1s is generous for macOS USB-serial round-trips.
    private let responseTimeout: TimeInterval = 1.0

    /// Creates a Yaesu portable CAT protocol instance.
    ///
    /// - Parameters:
    ///   - transport: Serial transport (typically a `/dev/cu.usbserial-*`
    ///     port). Baud rate is set by the transport, not this
    ///     protocol; see the per-radio factory in
    ///     ``RadioDefinition/Yaesu``.
    ///   - capabilities: Radio capability set. Usually one of the
    ///     ``RadioCapabilitiesDatabase/Yaesu/ft817`` /
    ///     ``RadioCapabilitiesDatabase/Yaesu/ft857`` etc. entries.
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    // MARK: - Frequency

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // FT-817 family has no per-VFO set-freq addressing on the
        // wire — the command always targets the currently-selected
        // VFO. `vfo` is accepted for CATProtocol conformance but
        // ignored here.
        let tenHzUnits = hz / 10
        let bcd = Self.encodeBCDBigEndian8(tenHzUnits)
        let frame = Data([bcd[0], bcd[1], bcd[2], bcd[3], 0x01])
        try await transport.write(frame)
        _ = try await readAckByte()
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let response = try await sendStatusCommand(opcode: 0x03,
                                                    expectedLength: 5)
        // bytes 0-3: BCD-BE frequency in 10-Hz units.
        let tenHzUnits = try Self.decodeBCDBigEndian8(response[0..<4])
        return tenHzUnits * 10
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let selector = try Self.modeSelector(for: mode)
        let frame = Data([selector, 0x00, 0x00, 0x00, 0x07])
        try await transport.write(frame)
        _ = try await readAckByte()
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let response = try await sendStatusCommand(opcode: 0x03,
                                                    expectedLength: 5)
        // byte 4: mode selector. Bit 7 = narrow flag; bits 0-6 = mode.
        let selector = response[4] & 0x7F
        return try Self.mode(fromSelector: selector, narrow: response[4] & 0x80 != 0)
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        let opcode: UInt8 = enabled ? 0x08 : 0x88
        let frame = Data([0x00, 0x00, 0x00, 0x00, opcode])
        try await transport.write(frame)
        _ = try await readAckByte()
    }

    public func getPTT() async throws -> Bool {
        let response = try await sendStatusCommand(opcode: 0xF7,
                                                    expectedLength: 1)
        // 0xFF = not transmitting; anything else = transmitting.
        return response[0] != 0xFF
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        // The FT-817 family only exposes a toggle (opcode 0x81),
        // not a "select A" / "select B" command. Without querying
        // the current VFO first we cannot honour a specific target
        // reliably. Rather than issue speculative toggles that
        // might land the operator on the wrong VFO, treat this as
        // a no-op — front-panel VFO management is the intended
        // workflow for this radio family.
    }

    // MARK: - SupportsSignalStrength

    public func getSignalStrength() async throws -> SignalStrength {
        // Get RX status = opcode 0xE7; byte 0 low nibble = S-meter
        // in 0-9 units (>9 = over S9). Cross-checked against Hamlib
        // `ft817_get_level()` for RIG_LEVEL_STRENGTH.
        let response = try await sendStatusCommand(opcode: 0xE7,
                                                    expectedLength: 1)
        let sMeter = Int(response[0] & 0x0F)
        // FT-817 reports S-units only; no dB-over-S9 resolution on
        // this hardware. Pass the raw byte through so downstream can
        // inspect if needed.
        return SignalStrength(sUnits: sMeter, raw: Int(response[0]))
    }

    // MARK: - Wire helpers

    /// Sends a 5-byte status query and reads the expected fixed-length
    /// response. Used for get-freq/mode (5-byte response, opcode 0x03),
    /// get-TX-status (1-byte, opcode 0xF7), and get-RX-status (1-byte,
    /// opcode 0xE7).
    ///
    /// Status commands do **not** consume an ACK byte — the response
    /// itself is the acknowledgement.
    private func sendStatusCommand(opcode: UInt8,
                                    expectedLength: Int) async throws -> Data {
        let frame = Data([0x00, 0x00, 0x00, 0x00, opcode])
        try await transport.write(frame)
        let response = try await transport.read(timeout: responseTimeout)
        guard response.count >= expectedLength else {
            throw RigError.invalidResponse
        }
        return response.prefix(expectedLength)
    }

    /// Reads the 1-byte ACK that terminates every set command.
    ///
    /// Returns the raw byte for callers that want to validate a
    /// rejection code. Hamlib's `ft817_read_ack()` note that
    /// non-zero ACKs are "not documented — none observed"; we
    /// accept any byte as success.
    @discardableResult
    private func readAckByte() async throws -> UInt8 {
        let response = try await transport.read(timeout: responseTimeout)
        guard let byte = response.first else {
            throw RigError.invalidResponse
        }
        return byte
    }

    // MARK: - BCD encoding

    /// Encodes a value into 4 bytes of 8-digit big-endian BCD.
    ///
    /// Each nibble is one decimal digit. Big-endian means the most
    /// significant digit lands in the high nibble of byte 0.
    ///
    /// For frequency: pass Hz/10 (the FT-817 family truncates to
    /// 10 Hz resolution).
    ///
    /// Cross-checked against Hamlib `to_bcd_be(data, freq/10, 8)`
    /// in `ft817_set_freq()`.
    ///
    /// - Parameter value: The value to encode. Must fit in 8 decimal
    ///   digits (0-99_999_999).
    /// - Returns: 4-byte big-endian BCD representation.
    internal static func encodeBCDBigEndian8(_ value: UInt64) -> [UInt8] {
        var digits: [UInt8] = []
        var v = value
        for _ in 0..<8 {
            digits.append(UInt8(v % 10))
            v /= 10
        }
        // digits[0] is least-significant. Pack from most-significant
        // end back into 4 bytes, high nibble first.
        var bytes = [UInt8](repeating: 0, count: 4)
        for i in 0..<4 {
            let high = digits[7 - 2 * i]
            let low  = digits[7 - 2 * i - 1]
            bytes[i] = (high << 4) | low
        }
        return bytes
    }

    /// Decodes 4 bytes of 8-digit big-endian BCD back into an
    /// integer. Inverse of ``encodeBCDBigEndian8(_:)``.
    ///
    /// - Parameter bytes: A 4-byte slice.
    /// - Returns: The decoded integer value.
    /// - Throws: ``RigError/invalidResponse`` if any nibble is not a
    ///   valid decimal digit (0-9).
    internal static func decodeBCDBigEndian8(_ bytes: Data.SubSequence) throws -> UInt64 {
        guard bytes.count == 4 else {
            throw RigError.invalidResponse
        }
        var value: UInt64 = 0
        for byte in bytes {
            let high = (byte >> 4) & 0x0F
            let low  = byte & 0x0F
            guard high < 10 && low < 10 else {
                throw RigError.invalidResponse
            }
            value = value * 100 + UInt64(high) * 10 + UInt64(low)
        }
        return value
    }

    // MARK: - Mode encoding

    /// Maps a Swift `Mode` value to the FT-817-family mode selector
    /// byte. Cross-checked against Hamlib `rigs/yaesu/ft817.c` command
    /// table entries `mode set main LSB` through `mode set main PKT`
    /// (lines 183-192).
    internal static func modeSelector(for mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb:      return 0x00
        case .usb:      return 0x01
        case .cw:       return 0x02
        case .cwR:      return 0x03
        case .am:       return 0x04
        case .fm:       return 0x08
        case .fmN:      return 0x88
        case .dataUSB, .dataLSB:
            // Hamlib maps both PKT-USB and PKT-LSB (DATA-USB/LSB) to
            // the same PKT selector (0x0C) — the FT-817 doesn't
            // distinguish upper vs lower on the PKT/DIG channel.
            return 0x0C
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by FT-817-family CAT"
            )
        }
    }

    /// Inverse of ``modeSelector(for:)``. Maps a selector byte back to
    /// a Swift `Mode`.
    ///
    /// - Parameter selector: The low 7 bits of the mode byte returned
    ///   by opcode `0x03`.
    /// - Parameter narrow: `true` if the narrow-mode bit (bit 7) is
    ///   set. Only meaningful for FM.
    internal static func mode(fromSelector selector: UInt8, narrow: Bool) throws -> Mode {
        switch selector {
        case 0x00: return .lsb
        case 0x01: return .usb
        case 0x02: return .cw
        case 0x03: return .cwR
        case 0x04: return .am
        case 0x08: return narrow ? .fmN : .fm
        case 0x0A: return .dataUSB   // DIG — collapsed to DATA-USB
        case 0x0C: return .dataUSB   // PKT — collapsed to DATA-USB
        default:
            throw RigError.invalidResponse
        }
    }
}
