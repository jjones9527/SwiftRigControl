import Foundation

/// Actor implementing the FT-1000MP-family pre-newcat binary CAT
/// protocol.
///
/// Covers Yaesu's 1990s HF flagship line: FT-1000MP (1995),
/// FT-1000MP MkV (2000), and FT-1000MP MkV Field (2001). All three
/// share the same wire protocol per Hamlib `rigs/yaesu/ft1000mp.c`
/// (which notes at line 132: "The FT1000MP MARK-V Field appears to
/// be identical to FT1000MP, whereas the FT1000MP MARK-V is a
/// FT1000MP with 200W").
///
/// Same 5-byte frame shape as the FT-817 family
/// (``YaesuPortableCAT``) but with three critical differences:
///
/// 1. **Little-endian BCD** frequency encoding
///    (Hamlib `to_bcd(data, freq/10, 8)` — no `_be` suffix), where
///    the FT-817 family uses big-endian. See
///    ``YaesuBinaryFrame/encodeBCDLittleEndian8(_:)``.
/// 2. **Mode selector lives in byte 3** (P4), and the high bit of
///    P4 tags VFO A (0x00-0x0B) vs VFO B (0x80-0x8B). The FT-817
///    family puts the mode in byte 0 with no VFO tag.
/// 3. **Fire-and-forget set commands** — no 1-byte ACK to read.
///    The FT-817 family reads an ACK after every set.
///
/// ## Frame layout
///
/// ```text
/// Set VFO-A freq: [ bcd0, bcd1, bcd2, bcd3, 0x0A ]   // opcode 0x0A
/// Set VFO-B freq: [ bcd0, bcd1, bcd2, bcd3, 0x8A ]   // opcode 0x8A
/// Set mode:       [ 0x00, 0x00, 0x00, sel,  0x0C ]   // opcode 0x0C
///                                    ^ high bit tags VFO B
/// Select VFO A:   [ 0x00, 0x00, 0x00, 0x00, 0x05 ]
/// Select VFO B:   [ 0x00, 0x00, 0x00, 0x01, 0x05 ]
/// PTT ON:         [ 0x00, 0x00, 0x00, 0x01, 0x0F ]
/// PTT OFF:        [ 0x00, 0x00, 0x00, 0x00, 0x0F ]
/// ```
///
/// Cross-checked against Hamlib `ft1000mp.c` command table lines
/// 168-217 and `to_bcd(p->p_cmd, freq / 10, 8)` at line 885.
///
/// ## Get frequency + mode
///
/// FT-1000MP does not respond to a single-opcode query the way
/// FT-817 does. Instead it uses opcode `0x10` "status update"
/// with P4 selecting the block:
///
/// - `[0,0,0,0x02,0x10]` = current-VFO block, 16 bytes.
/// - `[0,0,0,0x03,0x10]` = both VFOs, 32 bytes.
///
/// Response layout (16 bytes per VFO block, `FT1000MP_STATUS_UPDATE_LENGTH`
/// in Hamlib `ft1000mp.h`):
///
/// - Bytes 0-4: unused / reserved
/// - Bytes 5-8: **native binary** frequency (big-endian 32-bit int)
///   times `10/16` per the FT-1000MP's tuning-step quirk. Hamlib
///   line 963: `f = ((((((p[0]<<8) + p[1]) << 8) + p[2]) << 8) + p[3]) * 10 / 16`
/// - Byte 15: mode flags (bits 0-3 = mode selector; bit 7 = VFO
///   memory / narrow flag on some modes)
///
/// This is a genuinely weird encoding (not BCD) — the FT-1000MP's
/// PLL synthesises frequency in 1.5625 Hz units (= 10/16 Hz), which
/// is why Hamlib divides the raw binary word by 16 and multiplies
/// by 10. See `ft1000mp_get_freq()` at ft1000mp.c line 927.
///
/// For this release we implement setFrequency / setMode / setPTT
/// (the write paths that operators actually drive). getFrequency,
/// getMode, and getPTT throw `.unsupportedOperation` for now —
/// implementing the 16-byte status decode is a follow-up that
/// deserves its own dedicated review.
public actor YaesuFT1000MPCAT: CATProtocol {

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    // MARK: - Frequency

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        let tenHzUnits = hz / 10
        let bcd = YaesuBinaryFrame.encodeBCDLittleEndian8(tenHzUnits)
        // Opcode picks VFO: 0x0A for A, 0x8A for B.
        let opcode: UInt8 = (vfo == .b) ? 0x8A : 0x0A
        let frame = Data([bcd[0], bcd[1], bcd[2], bcd[3], opcode])
        try await transport.write(frame)
        // No ACK read per Hamlib ft1000mp_send_priv_cmd() (fire and
        // forget, line 1729).
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        // The status-update-block decoder isn't in this release.
        // See the type-level doc block for the format we'd need to
        // implement.
        throw RigError.unsupportedOperation(
            "getFrequency not yet implemented for FT-1000MP; use a "
            + "hardware validator to characterise the status-block "
            + "response before this can ship"
        )
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let selector = try Self.modeSelector(for: mode, vfo: vfo)
        // Frame layout: mode selector in byte 3 (P4), opcode 0x0C
        // in byte 4. Bytes 0-2 are zero.
        let frame = Data([0x00, 0x00, 0x00, selector, 0x0C])
        try await transport.write(frame)
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        throw RigError.unsupportedOperation(
            "getMode not yet implemented for FT-1000MP"
        )
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        // Per ncmd table entries 39 (PTT OFF) and 40 (PTT ON):
        //   [_,_,_,0x00,0x0F] = PTT off
        //   [_,_,_,0x01,0x0F] = PTT on
        let onOff: UInt8 = enabled ? 0x01 : 0x00
        let frame = Data([0x00, 0x00, 0x00, onOff, 0x0F])
        try await transport.write(frame)
    }

    public func getPTT() async throws -> Bool {
        throw RigError.unsupportedOperation(
            "getPTT not yet implemented for FT-1000MP"
        )
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        // Per ncmd table entries 4 (VFO A) and 5 (VFO B):
        //   [_,_,_,0x00,0x05] = select A
        //   [_,_,_,0x01,0x05] = select B
        let selector: UInt8 = (vfo == .b) ? 0x01 : 0x00
        let frame = Data([0x00, 0x00, 0x00, selector, 0x05])
        try await transport.write(frame)
    }

    // MARK: - Mode encoding

    /// Maps a Swift `Mode` + `VFO` to the FT-1000MP mode selector byte.
    /// The high bit tags VFO B; low nibble selects the mode.
    ///
    /// Cross-checked against Hamlib `ft1000mp.c` ncmd table entries
    /// 14-37 (VFO-A modes 0x00-0x0B, VFO-B modes 0x80-0x8B).
    internal static func modeSelector(for mode: Mode, vfo: VFO) throws -> UInt8 {
        let base: UInt8
        switch mode {
        case .lsb:      base = 0x00
        case .usb:      base = 0x01
        case .cw:       base = 0x02   // CW-USB
        case .cwR:      base = 0x03   // CW-LSB
        case .am:       base = 0x04
        case .fm:       base = 0x06
        case .fmN:      base = 0x07   // FMW? per Hamlib comment; interpretation
                                      // is uncertain — flagged for hardware
                                      // verification.
        case .rtty:     base = 0x08   // RTTY-LSB
        case .rttyR:    base = 0x09   // RTTY-USB
        case .dataLSB:  base = 0x0A
        case .dataUSB:
            // Hamlib table has DATA-LSB at 0x0A and DATA-FM at 0x0B —
            // no dedicated DATA-USB. Fall back to DATA-LSB rather
            // than throw; downstream apps generally treat DATA-USB
            // as the digital-mode default and the FT-1000MP's SSB
            // filter side is set separately via the CW-USB / CW-LSB
            // selectors.
            base = 0x0A
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by FT-1000MP CAT"
            )
        }
        return vfo == .b ? (base | 0x80) : base
    }
}
