import Foundation

/// CAT protocol implementation for Ten-Tec legacy radios (Jupiter TT-538, Pegasus TT-550).
///
/// The legacy Ten-Tec protocol uses simple ASCII commands terminated with CR (0x0D).
/// It is a purely unidirectional set-only protocol for most operations —
/// queries are not universally supported.
///
/// ## Command Format
/// ```
/// M<mode_char>\r                  — Set mode
/// N<CTF hi><CTF lo><FTF hi><FTF lo><BTF hi><BTF lo>\r
///                                 — Set VFO A frequency (6 binary bytes)
/// W<filter_byte>\r                — Set filter
/// X\r                             — Query signal strength (returns 3 bytes)
/// ?\r                             — Query firmware version
/// ```
///
/// ## Mode Codes
/// ```
/// '0' = AM   '1' = USB   '2' = LSB   '3' = CW   '4' = FM
/// ```
///
/// ## Frequency Encoding — Ten-Tec Tuning Factors
///
/// The `N` command payload is *not* ASCII digits — it is three 16-bit
/// big-endian tuning factors (CTF, FTF, BTF) computed from the desired
/// frequency, current mode, filter width, PBT offset, and (for CW) BFO.
///
/// Formulas (Hamlib `rigs/tentec/tentec.c::tentec_tuning_factor_calc`):
/// ```
/// fcor       = (mode == CW) ? 0 : (width / 2) + 200
/// mcor       = ±1 for LSB/USB/CW, 0 for AM/FM
/// cwbfo      = (mode == CW) ? priv->cwbfo : 0
/// adjtfreq   = freq_hz - 1250 + mcor * (fcor + pbt)
/// CTF        = (adjtfreq / 2500) + 18000
/// FTF        = floor((adjtfreq mod 2500) * 5.46)
/// BTF        = floor((fcor + pbt + cwbfo + 8000) * 2.73)
/// ```
///
/// Pre-fix code sent a 6-byte zero-padded ASCII decimal string — the
/// Jupiter/Pegasus firmware doesn't understand that format at all, so
/// the radio ignored every frequency set. This implementation ports
/// the Hamlib tuning-factor calculation directly.
///
/// Reference: Hamlib `rigs/tentec/tentec.c:181` and `rigs/tentec/tentec.c:228`.
public actor TenTecLegacyProtocol:
    CATProtocol,
    SupportsSignalStrength
{
    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// Command terminator (CR = 0x0D)
    private static let cr: UInt8 = 0x0D

    /// Response timeout
    private let responseTimeout: TimeInterval = 2.0

    /// Cached current frequency (legacy protocol has no reliable get-frequency query)
    private var cachedFrequency: UInt64 = 14_000_000

    /// Cached current mode — required to compute the tuning factors.
    private var cachedMode: Mode = .usb

    /// Current filter width in Hz. Defaults match Hamlib's
    /// `tentec_init` (`priv->width = kHz(6)` for AM start-up state).
    private var currentWidthHz: Int = 2400

    /// Passband tuning offset in Hz. Defaults to 0 like Hamlib.
    private var passbandTuningHz: Int = 0

    /// CW BFO offset in Hz. Defaults to 1000 like Hamlib's `tentec_init`.
    private var cwBFOHz: Int = 1000

    /// Creates a legacy Ten-Tec protocol instance (Jupiter, Pegasus).
    ///
    /// - Parameters:
    ///   - transport: Serial transport to communicate over.
    ///   - capabilities: Capability set for the chosen model.
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
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

    /// Sets the VFO A frequency using Ten-Tec's tuning-factor encoding.
    ///
    /// The legacy Ten-Tec protocol only supports setting VFO A. The
    /// `vfo` argument is accepted for `CATProtocol` conformance but
    /// ignored on-wire.
    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        let (ctf, ftf, btf) = Self.tuningFactors(
            freqHz: Int(hz),
            mode: cachedMode,
            widthHz: currentWidthHz,
            pbtHz: passbandTuningHz,
            cwBFOHz: cwBFOHz
        )

        var bytes: [UInt8] = [0x4E] // 'N'
        bytes.append(UInt8(truncatingIfNeeded: ctf >> 8))
        bytes.append(UInt8(truncatingIfNeeded: ctf & 0xFF))
        bytes.append(UInt8(truncatingIfNeeded: ftf >> 8))
        bytes.append(UInt8(truncatingIfNeeded: ftf & 0xFF))
        bytes.append(UInt8(truncatingIfNeeded: btf >> 8))
        bytes.append(UInt8(truncatingIfNeeded: btf & 0xFF))
        bytes.append(Self.cr)

        try await transport.write(Data(bytes))
        cachedFrequency = hz
        // Legacy protocol does not respond to set commands
    }

    /// Ports Hamlib `tentec_tuning_factor_calc` (rigs/tentec/tentec.c:181).
    ///
    /// - Returns: `(ctf, ftf, btf)` — three 16-bit tuning factors that
    ///   the `N` command sends to the radio as big-endian bytes.
    /// - Note: Exposed `internal static` so unit tests can pin the byte
    ///   patterns against Hamlib without going through the actor.
    internal static func tuningFactors(
        freqHz: Int,
        mode: Mode,
        widthHz: Int,
        pbtHz: Int,
        cwBFOHz: Int
    ) -> (ctf: Int, ftf: Int, btf: Int) {
        let mcor: Int
        var fcor: Int = (widthHz / 2) + 200
        var cwbfoLocal: Int = 0

        switch mode {
        case .am, .fm:
            mcor = 0
        case .cw, .cwR:
            mcor = -1
            cwbfoLocal = cwBFOHz
            fcor = 0
        case .lsb:
            mcor = -1
        case .usb:
            mcor = 1
        default:
            // Unsupported modes fall back to USB semantics — matches
            // Hamlib's `default: mcor = 1` branch (tentec.c:211).
            mcor = 1
        }

        let adjtfreq = freqHz - 1250 + mcor * (fcor + pbtHz)

        // C truncates toward zero; Swift's `/` on Int also truncates
        // toward zero, so this matches Hamlib exactly for the sign
        // conventions in play.
        let ctf = (adjtfreq / 2500) + 18000
        let ftf = Int(floor(Double(adjtfreq % 2500) * 5.46))
        let btf = Int(floor(Double(fcor + pbtHz + cwbfoLocal + 8000) * 2.73))

        return (ctf, ftf, btf)
    }

    /// Returns the cached frequency (legacy protocol has no reliable frequency query).
    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        return cachedFrequency
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        guard let modeChar = legacyModeCode(mode) else {
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Ten-Tec legacy protocol")
        }
        let bytes: [UInt8] = [0x4D, modeChar, Self.cr]  // 'M', modeChar, CR
        try await transport.write(Data(bytes))
        cachedMode = mode
    }

    /// Returns the cached mode (legacy protocol has no mode query command).
    public func getMode(vfo: VFO) async throws -> Mode {
        return cachedMode
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Legacy Ten-Tec radios use hardware PTT only — no CAT PTT command
        throw RigError.unsupportedOperation("PTT via CAT not supported on Ten-Tec legacy radios")
    }

    public func getPTT() async throws -> Bool {
        throw RigError.unsupportedOperation("PTT via CAT not supported on Ten-Tec legacy radios")
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        // Legacy protocol does not support VFO B switching
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // X\r queries signal strength — returns 3 bytes
        let bytes: [UInt8] = [0x58, Self.cr]  // 'X', CR
        try await transport.write(Data(bytes))

        let data = try await transport.readUntil(terminator: Self.cr, timeout: responseTimeout)
        var response = [UInt8](data)
        if response.last == Self.cr { response.removeLast() }

        guard response.count >= 1 else { throw RigError.invalidResponse }
        let raw = Int(response[0])

        // Scale: 0–255 raw, roughly 28 units per S-unit
        let sUnits = min(raw / 28, 9)
        let overS9 = sUnits >= 9 ? min((raw - 252) / 4, 60) : 0
        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: raw)
    }

    // MARK: - Private Helpers

    private func legacyModeCode(_ mode: Mode) -> UInt8? {
        switch mode {
        case .am:   return 0x30  // '0'
        case .usb:  return 0x31  // '1'
        case .lsb:  return 0x32  // '2'
        case .cw:   return 0x33  // '3'
        case .fm:   return 0x34  // '4'
        case .cwR, .rtty, .rttyR, .dataUSB, .dataLSB, .dataFM, .fmN, .wfm:
            return nil
        }
    }
}
