import Foundation

/// CAT protocol implementation for Ten-Tec legacy radios (Jupiter TT-538, Pegasus TT-550).
///
/// The legacy Ten-Tec protocol uses simple ASCII commands terminated with CR (0x0D).
/// It is a purely unidirectional set-only protocol for most operations —
/// queries are not universally supported.
///
/// ## Command Format
/// ```
/// M<mode_char>\r          — Set mode
/// N<6-byte freq>\r        — Set VFO A frequency (6 ASCII-encoded bytes)
/// W<filter_byte>\r        — Set filter
/// X\r                     — Query signal strength (returns 3 bytes)
/// ?\r                     — Query firmware version
/// ```
///
/// ## Mode Codes
/// ```
/// '0' = AM   '1' = USB   '2' = LSB   '3' = CW   '4' = FM
/// ```
///
/// ## Frequency Encoding
/// The Jupiter/Pegasus frequency command `N` uses a 6-byte encoding where each byte
/// represents two BCD digits of the frequency in Hz. This is a proprietary Ten-Tec format
/// derived from their CTF/FTF tuning factor scheme. The encoding for frequency `f` (Hz):
/// - Byte 0: MHz high digit
/// - Byte 1: MHz low digit
/// - Bytes 2-5: remaining digits
///
/// In practice, the simplest compatible encoding is to send the frequency as a
/// 6-character zero-padded decimal ASCII string (matches Hamlib's implementation in `tentec.c`).
///
/// Reference: Hamlib `rigs/tentec/tentec.c`
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

    /// Cached current mode
    private var cachedMode: Mode = .usb

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

    /// Sets the VFO A frequency.
    ///
    /// The legacy Ten-Tec protocol only supports setting VFO A.
    /// The frequency is encoded as 6 ASCII bytes representing the Hz value, zero-padded.
    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // Legacy protocol only controls VFO A — ignore VFO parameter
        // Encode as 6-byte zero-padded decimal (Hamlib tentec.c approach)
        let freqStr = String(format: "%06llu", hz)
        let payload = Array(freqStr.utf8)
        var bytes: [UInt8] = [0x4E]  // 'N'
        bytes.append(contentsOf: payload)
        bytes.append(Self.cr)
        try await transport.write(Data(bytes))
        cachedFrequency = hz
        // Legacy protocol does not respond to set commands
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
