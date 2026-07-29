import Foundation

/// Actor implementing the FT-847-family pre-newcat binary CAT
/// protocol.
///
/// Covers Yaesu's satellite-friendly all-band transceiver family:
/// FT-847 (1998), FT-847UNI (2000 unidirectional CAT variant),
/// FT-650 (1990s 24-56 MHz specialist — trivially the same protocol
/// with narrower frequency range), and mcHF QRP (a hobbyist kit that
/// speaks the same wire protocol).
///
/// Shares the 5-byte frame shape and big-endian BCD frequency
/// encoding with the FT-817 family (``YaesuPortableCAT``), but
/// differs in two ways worth calling out:
///
/// 1. **Fire-and-forget set commands.** The radio does not send an
///    ACK byte back after a set command. Hamlib's `ft847_send_priv_cmd()`
///    calls `write_block()` and returns immediately (`ft847.c` line
///    ~1123). The FT-817 family reads a 1-byte ACK; the FT-847 does
///    not. Attempting to read an ACK where none exists would time
///    out and mask real errors.
///
/// 2. **Satellite mode changes the opcode nibble.** When sat mode is
///    off (the default), commands use the "main" opcode set
///    (`0x01` set freq, `0x07` set mode, `0x03` get freq/mode). When
///    sat mode is on (toggled with `0x4E` / `0x8E`), the same
///    logical commands use `0x11` / `0x21` for SAT RX / SAT TX
///    freq, and `0x03` / `0x13` / `0x23` for the corresponding
///    get-freq responses. Hamlib's `opcode_vfo()` (line 1132)
///    patches the opcode nibble in-place based on VFO + sat state.
///    This release implements sat mode as a stateful actor property
///    that consumers can toggle explicitly via ``setSatelliteMode(_:)``.
///
/// ## Frame layout (non-sat mode)
///
/// ```text
/// Set freq:      [ bcd0, bcd1, bcd2, bcd3, 0x01 ]
/// Set mode:      [ sel,  0x00, 0x00, 0x00, 0x07 ]
/// Get freq/mode: [ 0x00, 0x00, 0x00, 0x00, 0x03 ]     → 5-byte response
/// Sat ON:        [ 0x00, 0x00, 0x00, 0x00, 0x4E ]
/// Sat OFF:       [ 0x00, 0x00, 0x00, 0x00, 0x8E ]
/// PTT ON:        [ 0x00, 0x00, 0x00, 0x00, 0x08 ]
/// PTT OFF:       [ 0x00, 0x00, 0x00, 0x01, 0x88 ]
/// ```
///
/// Cross-checked against Hamlib `ft847.c` ncmd table lines 236-318.
///
/// ## FT-847UNI unidirectional variant
///
/// FT-847UNI (and FT-650) are marked `UNIDIRECTIONAL` in Hamlib
/// (`ft847.c` line 325):
///
/// ```c
/// #define UNIDIRECTIONAL (rig->caps->rig_model == RIG_MODEL_FT847UNI
///                     || rig->caps->rig_model == RIG_MODEL_FT650)
/// ```
///
/// When set, Hamlib caches state locally and never issues status
/// reads — the CAT connection is write-only. Our equivalent is the
/// `isUnidirectional: Bool` initializer parameter. When true, all
/// getters throw `.unsupportedOperation`.
public actor YaesuFT847CAT: CATProtocol {

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// `true` when this instance targets an FT-847UNI (or FT-650)
    /// which cannot service read queries. Getters throw when this
    /// flag is set; setters continue to write.
    public let isUnidirectional: Bool

    /// Current satellite-mode state. Toggling this changes which
    /// opcode nibble the get-freq / set-freq commands emit.
    private var satelliteModeEnabled: Bool = false

    /// How long to wait for a status response. Sat mode changes take
    /// a moment to settle on some units — 1 second is comfortable.
    private let responseTimeout: TimeInterval = 1.0

    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities,
        isUnidirectional: Bool = false
    ) {
        self.transport = transport
        self.capabilities = capabilities
        self.isUnidirectional = isUnidirectional
    }

    // MARK: - Satellite mode

    /// Toggles satellite mode on the radio.
    ///
    /// In satellite mode, get-freq / set-freq commands operate on
    /// the sat-RX and sat-TX VFOs instead of the main VFO. Callers
    /// generally don't need to touch this — the default is sat off.
    public func setSatelliteMode(_ enabled: Bool) async throws {
        let opcode: UInt8 = enabled ? 0x4E : 0x8E
        let frame = Data([0x00, 0x00, 0x00, 0x00, opcode])
        try await transport.write(frame)
        satelliteModeEnabled = enabled
    }

    /// Current satellite-mode state (readable by tests).
    public var isSatelliteModeEnabled: Bool {
        satelliteModeEnabled
    }

    // MARK: - Frequency

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        let tenHzUnits = hz / 10
        let bcd = YaesuBinaryFrame.encodeBCDBigEndian8(tenHzUnits)
        // Non-sat: 0x01. Sat RX: 0x11. Sat TX: 0x21.
        let opcode = setFreqOpcode(vfo: vfo)
        let frame = Data([bcd[0], bcd[1], bcd[2], bcd[3], opcode])
        try await transport.write(frame)
        // Fire and forget — no ACK per Hamlib line 1217.
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        try requireBidirectional()
        // Non-sat: 0x03. Sat RX: 0x13. Sat TX: 0x23.
        let opcode = getFreqOpcode(vfo: vfo)
        let response = try await sendStatusCommand(opcode: opcode,
                                                    expectedLength: 5)
        // bytes 0-3: BCD-BE frequency in 10-Hz units per Hamlib
        // line 1290: `10 * from_bcd_be(data, 8)`.
        let tenHzUnits = try YaesuBinaryFrame.decodeBCDBigEndian8(response[0..<4])
        return tenHzUnits * 10
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let selector = try Self.modeSelector(for: mode)
        // Mode selector in byte 0 (P1); opcode 0x07 in byte 4.
        // Sat mode changes only the opcode nibble to match VFO —
        // for setMode we always use 0x07 (main); the FT-847's SAT
        // mode commands (0x17 SAT RX, 0x27 SAT TX) are handled by
        // toggling satellite mode explicitly and re-routing frequency
        // commands. Set-mode is main-only per operator intent.
        let frame = Data([selector, 0x00, 0x00, 0x00, 0x07])
        try await transport.write(frame)
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try requireBidirectional()
        let opcode = getFreqOpcode(vfo: vfo)
        let response = try await sendStatusCommand(opcode: opcode,
                                                    expectedLength: 5)
        // Byte 4: mode selector per Hamlib line 1294.
        return try Self.mode(fromSelector: response[4])
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        // Per ncmd table lines 240-241:
        //   [_,_,_,_,0x08] = PTT on
        //   [_,_,_,0x01,0x88] = PTT off  (P4 = 0x01, unusual)
        let frame: Data
        if enabled {
            frame = Data([0x00, 0x00, 0x00, 0x00, 0x08])
        } else {
            frame = Data([0x00, 0x00, 0x00, 0x01, 0x88])
        }
        try await transport.write(frame)
    }

    public func getPTT() async throws -> Bool {
        try requireBidirectional()
        // Get TX status = 0xF7 → 1-byte response. Per Hamlib
        // `ft847_get_ptt()` (ft847.c line 1673):
        //   *ptt = (p->tx_status & 0x80) ? RIG_PTT_OFF : RIG_PTT_ON;
        // Bit 7 SET means PTT OFF (RX); bit 7 CLEAR means PTT ON.
        // Prior to the v1.2.0 audit fix Swift had this inverted —
        // getPTT reported false when the radio was transmitting.
        let response = try await sendStatusCommand(opcode: 0xF7,
                                                    expectedLength: 1)
        return response[0] & 0x80 == 0
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        // FT-847 has no explicit "select VFO" — main / sub are picked
        // by which get / set command opcode you send. Treat this as
        // a no-op; the VFO parameter to setFrequency / getFrequency
        // does the routing.
    }

    // MARK: - Helpers

    private func setFreqOpcode(vfo: VFO) -> UInt8 {
        // Non-sat: always 0x01 regardless of VFO.
        // Sat mode: SAT RX = 0x11 (VFO A/main), SAT TX = 0x21 (VFO B/sub).
        guard satelliteModeEnabled else { return 0x01 }
        return vfo == .b ? 0x21 : 0x11
    }

    private func getFreqOpcode(vfo: VFO) -> UInt8 {
        guard satelliteModeEnabled else { return 0x03 }
        return vfo == .b ? 0x23 : 0x13
    }

    private func sendStatusCommand(opcode: UInt8,
                                    expectedLength: Int) async throws -> Data {
        let frame = Data([0x00, 0x00, 0x00, 0x00, opcode])
        try await transport.write(frame)
        return try await transport.readExact(count: expectedLength,
                                             timeout: responseTimeout)
    }

    private func requireBidirectional() throws {
        if isUnidirectional {
            throw RigError.unsupportedOperation(
                "FT-847UNI / FT-650 are unidirectional CAT — the radio "
                + "does not send status responses. Use the front panel."
            )
        }
    }

    // MARK: - Mode encoding

    /// Cross-checked against Hamlib `ft847.c` ncmd table lines
    /// 249-258 for main mode selectors. FT-847 supports narrow
    /// variants for CW and AM in addition to FM-N.
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
            // FT-847 has no DIG/PKT mode in its command table. Fall
            // back to USB / LSB respectively — most digital modes
            // operators use on the FT-847 configure the sound-card
            // interface for USB/LSB anyway.
            return mode == .dataLSB ? 0x00 : 0x01
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by FT-847 CAT"
            )
        }
    }

    /// Inverse of ``modeSelector(for:)``.
    internal static func mode(fromSelector selector: UInt8) throws -> Mode {
        switch selector {
        case 0x00: return .lsb
        case 0x01: return .usb
        case 0x02: return .cw
        case 0x03: return .cwR
        case 0x04: return .am
        case 0x08: return .fm
        case 0x88: return .fmN
        case 0x82, 0x83:    // CW-N, CW-R-N — narrow variants
            return .cw
        case 0x84:          // AM-N
            return .am
        default:
            throw RigError.invalidResponse
        }
    }
}
