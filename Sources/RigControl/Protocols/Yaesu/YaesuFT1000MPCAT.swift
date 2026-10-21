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
///    `YaesuBinaryFrame.encodeBCDLittleEndian8(_:)`.
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
/// - Bytes 1-4: **native binary** frequency (big-endian 32-bit int)
///   times `10/16` per the FT-1000MP's tuning-step quirk. Hamlib
///   line 963: `f = ((((((p[0]<<8) + p[1]) << 8) + p[2]) << 8) + p[3]) * 10 / 16`
/// - Byte 7: mode; byte 8 bit 7 carries the mode extension flag.
///
/// This is a genuinely weird encoding (not BCD) — the FT-1000MP's
/// PLL synthesises frequency in 1.5625 Hz units (= 10/16 Hz), which
/// is why Hamlib divides the raw binary word by 16 and multiplies
/// by 10. See `ft1000mp_get_freq()` at ft1000mp.c line 927.
///
/// ## FT-920
///
/// The FT-920 (Hamlib `rigs/yaesu/ft920.c`) uses the same opcodes —
/// `0x0A` / `0x8A` frequency, `0x0C` mode with the VFO-B high bit,
/// `0x0F` PTT, `0x05` VFO select (`ft920.c:351-376`) — but its own mode
/// table, so it runs on this actor with ``Family/ft920``.
public actor YaesuFT1000MPCAT: CATProtocol, SupportsSplit, SupportsRIT, SupportsXIT,
    SupportsSignalStrength, SupportsTXMeters {

    static let responseTimeout: TimeInterval = 1.0

    /// Which radio family's mode table to use.
    public enum Family: Sendable, Equatable {
        /// FT-1000MP, MkV and MkV Field (`ft1000mp.c`).
        case ft1000mp
        /// FT-920 (`ft920.c`): DATA-L `0x08`, DATA-U `0x0A`,
        /// DATA-F `0x0B`, no separate RTTY selector.
        case ft920
    }

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// The mode-table family this instance encodes for.
    public let family: Family

    /// Creates an FT-1000MP-family protocol instance over the given
    /// transport.
    ///
    /// - Parameters:
    ///   - transport: Serial transport.
    ///   - capabilities: Radio capability set.
    ///   - family: Mode-table family. Defaults to ``Family/ft1000mp``.
    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities,
        family: Family = .ft1000mp
    ) {
        self.transport = transport
        self.capabilities = capabilities
        self.family = family
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
        let status = try await readVFOStatus()
        return try Self.frequency(fromStatus: status, vfo: vfo, family: family)
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let selector = try Self.modeSelector(for: mode, vfo: vfo, family: family)
        // Frame layout: mode selector in byte 3 (P4), opcode 0x0C
        // in byte 4. Bytes 0-2 are zero.
        let frame = Data([0x00, 0x00, 0x00, selector, 0x0C])
        try await transport.write(frame)
        if family == .ft920 {
            // This API has no passband-width parameter, so match Hamlib's
            // normal-width path after every FT-920 mode change.
            let filterSelector: UInt8 = (vfo == .b || vfo == .sub) ? 0x80 : 0x00
            try await transport.write(Data([0x00, 0x00, 0x00, filterSelector, 0x8C]))
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let status = try await readVFOStatus()
        return try Self.mode(fromStatus: status, vfo: vfo, family: family)
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
        guard family == .ft920 else {
            // Hamlib deliberately does not advertise get_ptt for the
            // FT-1000MP family even though its status flags contain an
            // RX/TX bit. Keep the public contract equally conservative.
            throw RigError.unsupportedOperation(
                "getPTT is not supported by Hamlib for FT-1000MP CAT"
            )
        }
        let flags = try await readFlags()
        return flags[flags.startIndex] & 0x80 != 0
    }

    // MARK: - Split

    public func setSplit(_ enabled: Bool) async throws {
        try await transport.write(Data([0x00, 0x00, 0x00, enabled ? 0x01 : 0x00, 0x01]))
    }

    public func getSplit() async throws -> Bool {
        let flags = try await readFlags()
        return flags[flags.startIndex] & 0x03 != 0
    }

    // MARK: - Clarifier (RIT / XIT)

    public func setRIT(_ state: RITXITState) async throws {
        try validateClarifierOffset(state.offset)
        let offset = state.enabled ? state.offset : 0
        try await setClarifierEnabled(state.enabled, transmit: false)
        try await setClarifierOffset(offset)
    }

    public func getRIT() async throws -> RITXITState {
        let status = try await readVFOStatus()
        let offset = try Self.clarifierOffset(fromStatus: status, family: family)
        let enabled = family == .ft1000mp
            ? try Self.clarifierEnabled(fromStatus: status, transmit: false)
            : offset != 0
        return RITXITState(enabled: enabled, offset: offset)
    }

    public func setXIT(_ state: RITXITState) async throws {
        try validateClarifierOffset(state.offset)
        let offset = state.enabled ? state.offset : 0
        try await setClarifierEnabled(state.enabled, transmit: true)
        try await setClarifierOffset(offset)
    }

    public func getXIT() async throws -> RITXITState {
        let status = try await readVFOStatus()
        let offset = try Self.clarifierOffset(fromStatus: status, family: family)
        let enabled = family == .ft1000mp
            ? try Self.clarifierEnabled(fromStatus: status, transmit: true)
            : offset != 0
        return RITXITState(enabled: enabled, offset: offset)
    }

    // MARK: - Metering

    public func getSignalStrength() async throws -> SignalStrength {
        let raw = try await readMeter(selector: 0x00)
        let dBRelativeToS9 = Self.signalDBRelativeToS9(raw: raw)
        if dBRelativeToS9 > 0 {
            return SignalStrength(sUnits: 9, overS9: Int(dBRelativeToS9.rounded()), raw: raw)
        }
        return SignalStrength(
            sUnits: Int(((dBRelativeToS9 + 54) / 6).rounded(.down)),
            raw: raw
        )
    }

    public func getRFPowerOut() async throws -> MeterReading {
        try await relativeMeter(selector: 0x80, kind: .rfPower)
    }

    public func getALC() async throws -> MeterReading {
        try await relativeMeter(selector: 0x81, kind: .alc)
    }

    public func getComp() async throws -> MeterReading {
        try await relativeMeter(selector: 0x83, kind: .comp)
    }

    public func getSWR() async throws -> MeterReading {
        try await relativeMeter(selector: 0x85, kind: .swr)
    }

    public func getVoltage() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Voltage meter not supported by FT-1000MP CAT")
    }

    public func getCurrent() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Current meter not supported by FT-1000MP CAT")
    }

    private func relativeMeter(selector: UInt8,
                               kind: MeterReading.Kind) async throws -> MeterReading {
        let raw = try await readMeter(selector: selector)
        return MeterReading(kind: kind, raw: raw, normalized: Double(raw) / 255.0)
    }

    private func readMeter(selector: UInt8) async throws -> Int {
        guard family == .ft1000mp else {
            throw RigError.unsupportedOperation("FT-920 CAT does not expose this meter")
        }
        let response = try await readBlock(
            frame: [selector, selector, selector, selector, 0xF7],
            length: 5
        )
        return Int(response[response.startIndex])
    }

    private func validateClarifierOffset(_ offset: Int) throws {
        guard (-9_999...9_999).contains(offset) else {
            throw RigError.invalidParameter("RIT/XIT offset must be between -9999 and +9999 Hz")
        }
    }

    private func setClarifierEnabled(_ enabled: Bool, transmit: Bool) async throws {
        let selector: UInt8
        if transmit {
            selector = enabled ? 0x81 : 0x80
        } else {
            selector = enabled ? 0x01 : 0x00
        }
        try await transport.write(Data([0x00, 0x00, 0x00, selector, 0x09]))
    }

    private func setClarifierOffset(_ offset: Int) async throws {
        let magnitude = abs(offset)
        let tens = magnitude % 1_000 / 10
        let kilohertz = magnitude / 1_000
        let lowBCD = UInt8((tens / 10) << 4 | (tens % 10))
        let highBCD = UInt8((kilohertz / 10) << 4 | (kilohertz % 10))
        let sign: UInt8 = offset < 0 ? 0xFF : 0x00
        try await transport.write(Data([lowBCD, highBCD, sign, 0xFF, 0x09]))
    }

    // MARK: - Status decoding

    private func readVFOStatus() async throws -> Data {
        let length = family == .ft920 ? 28 : 32
        return try await readBlock(frame: [0x00, 0x00, 0x00, 0x03, 0x10], length: length)
    }

    private func readFlags() async throws -> Data {
        let parameter: UInt8 = family == .ft920 ? 0x01 : 0x00
        let length = family == .ft920 ? 8 : 5
        return try await readBlock(frame: [0x00, 0x00, 0x00, parameter, 0xFA], length: length)
    }

    private func readBlock(frame: [UInt8], length: Int) async throws -> Data {
        try await transport.flush()
        try await transport.write(Data(frame))
        return try await transport.readExact(count: length, timeout: Self.responseTimeout)
    }

    internal static func frequency(fromStatus status: Data, vfo: VFO,
                                   family: Family) throws -> UInt64 {
        let offset: Int
        switch (family, vfo) {
        case (.ft1000mp, .b), (.ft1000mp, .sub): offset = 0x11
        case (.ft1000mp, _): offset = 0x01
        case (.ft920, .b), (.ft920, .sub): offset = 0x0F
        case (.ft920, _): offset = 0x01
        }
        guard status.count >= offset + 4 else { throw RigError.invalidResponse }
        var raw: UInt64 = 0
        for byte in status[offset..<(offset + 4)] {
            raw = (raw << 8) | UInt64(byte)
        }
        return family == .ft1000mp ? raw * 10 / 16 : raw
    }

    internal static func mode(fromStatus status: Data, vfo: VFO,
                              family: Family) throws -> Mode {
        let modeOffset: Int
        switch (family, vfo) {
        case (.ft1000mp, .b), (.ft1000mp, .sub): modeOffset = 0x17
        case (.ft1000mp, _): modeOffset = 0x07
        case (.ft920, .b), (.ft920, .sub): modeOffset = 0x15
        case (.ft920, _): modeOffset = 0x07
        }
        guard status.count > modeOffset else { throw RigError.invalidResponse }
        if family == .ft920 {
            switch status[modeOffset] & 0x7F {
            case 0x00: return .lsb
            case 0x40: return .usb
            case 0x01: return .cwR
            case 0x41: return .cw
            case 0x02: return .am
            case 0x03: return .fm
            case 0x04: return .dataLSB
            case 0x05: return .dataUSB
            case 0x06: return .dataFM
            default: throw RigError.invalidResponse
            }
        }

        guard status.count > modeOffset + 1 else { throw RigError.invalidResponse }
        let extended = status[modeOffset + 1] & 0x80 != 0
        switch status[modeOffset] & 0x07 {
        case 0x00: return .lsb
        case 0x01: return .usb
        case 0x02: return extended ? .cw : .cwR
        case 0x03: return .am
        case 0x04: return .fm
        case 0x05: return extended ? .rttyR : .rtty
        case 0x06: return extended ? .dataFM : .dataLSB
        default: throw RigError.invalidResponse
        }
    }

    internal static func clarifierOffset(fromStatus status: Data,
                                         family: Family) throws -> Int {
        guard status.count >= 7 else { throw RigError.invalidResponse }
        let raw = UInt16(status[5]) << 8 | UInt16(status[6])
        if family == .ft920 {
            return Int(Int16(bitPattern: raw))
        }
        return Int(Int16(bitPattern: raw)) * 10 / 16
    }

    internal static func clarifierEnabled(fromStatus status: Data,
                                          transmit: Bool) throws -> Bool {
        guard status.count > 9 else { throw RigError.invalidResponse }
        let mask: UInt8 = transmit ? 0x01 : 0x02
        return status[9] & mask != 0
    }

    /// Piecewise-linear interpolation of Hamlib's `FT1000MP_STR_CAL` table.
    internal static func signalDBRelativeToS9(raw: Int) -> Double {
        let points: [(raw: Int, dB: Double)] = [
            (0, -60), (17, -54), (17, -48), (34, -42), (51, -36),
            (68, -30), (85, -24), (102, -18), (119, -12),
            (136, -6), (160, 0), (255, 60),
        ]
        let value = max(0, min(255, raw))
        guard value > points[0].raw else { return points[0].dB }
        for index in 1..<points.count where value <= points[index].raw {
            let lower = points[index - 1]
            let upper = points[index]
            guard upper.raw != lower.raw else { return upper.dB }
            let fraction = Double(value - lower.raw) / Double(upper.raw - lower.raw)
            return lower.dB + fraction * (upper.dB - lower.dB)
        }
        return points[points.count - 1].dB
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
    internal static func modeSelector(for mode: Mode, vfo: VFO,
                                      family: Family = .ft1000mp) throws -> UInt8 {
        let base: UInt8
        if family == .ft920 {
            base = try ft920ModeBase(for: mode)
            return vfo == .b ? (base | 0x80) : base
        }
        switch mode {
        case .lsb:      base = 0x00
        case .usb:      base = 0x01
        case .cw:       base = 0x03   // Hamlib maps CW to CW-USB
        case .cwR:      base = 0x02   // and CWR to CW-LSB
        case .am:       base = 0x04
        case .fm:       base = 0x06
        case .rtty:     base = 0x08   // RTTY-LSB
        case .rttyR, .dataUSB: base = 0x09 // RTTY-USB / PKT-USB
        case .dataLSB:  base = 0x0A
        case .dataFM:   base = 0x0B
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by FT-1000MP CAT"
            )
        }
        return vfo == .b ? (base | 0x80) : base
    }

    /// FT-920 mode parameter (VFO-A form), per `ft920.c:109-119` and the
    /// mapping in `ft920_set_mode` (`ft920.c:975-1009`): CW is CW-USB,
    /// AM / FM are the wide variants, and RTTY / PKT-LSB share DATA-L.
    internal static func ft920ModeBase(for mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb: return 0x00
        case .usb: return 0x01
        case .cw: return 0x02
        case .am: return 0x04
        case .fm: return 0x06
        case .rtty, .dataLSB: return 0x08
        case .dataUSB: return 0x0A
        case .dataFM: return 0x0B
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by FT-920 CAT"
            )
        }
    }
}
