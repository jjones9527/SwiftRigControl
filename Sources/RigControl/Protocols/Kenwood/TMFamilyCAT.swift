import Foundation

/// Actor implementing the Kenwood TM-family CAT protocol.
///
/// Covers the TM-D710(G) and TM-V71(A) dual-band FM mobile
/// transceivers (2m + 70cm). Both share Hamlib's
/// `rigs/kenwood/tmd710.c` backend and use the same wire protocol.
///
/// Related but distinct from ``THD72Protocol``:
///
/// - **Same:** CR (`\r`) terminator, `TX` / `RX` PTT (no trailing
///   digit).
/// - **Different:** the `FO` command uses **13 comma-separated
///   fields**, not the fixed-position ASCII string TH-D72 / TH-D74
///   use. VFO is embedded as field 0 (hex), not selected via a
///   separate `BC` command.
///
/// ## FO command format
///
/// Per Hamlib `rigs/kenwood/tmd710.c` `tmd710_push_fo()`:
///
/// ```text
/// FO <vfo>,<freq>,<step>,<shift>,<reverse>,<tone>,<ct>,<dcs>,
///    <toneFreq>,<ctFreq>,<dcsVal>,<offset>,<mode>
/// ```
///
/// - `vfo` — 1 digit (0=A/main, 1=B/sub). Written with `%1d`; read
///   as hex `%x` — the printf/scanf asymmetry is Hamlib's, not
///   ours.
/// - `freq` — 10 digits in Hz, zero-padded (`%010.0f`).
/// - `step` through `dcs` — 1 digit each (0/1 flags or small enums).
/// - `toneFreq`, `ctFreq` — 2 digits each.
/// - `dcsVal` — 3 digits.
/// - `offset` — 8 digits (repeater offset in Hz).
/// - `mode` — 1 digit (0=FM, 1=FM-N, 2=AM).
///
/// The radio echoes the entire FO string on both set and get. On
/// set, we fetch → mutate one field → send back — same
/// "modify-in-place" pattern as the TH-D72 backend, matching
/// Hamlib's approach.
public actor TMFamilyCAT:
    CATProtocol,
    SupportsSignalStrength
{

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    private let responseTimeout: TimeInterval = 2.0

    /// CR terminator used by TH-series Kenwood handhelds and mobiles
    /// (EOM_TH in Hamlib).
    private static let terminator: UInt8 = 0x0D

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

    // MARK: - Frequency

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        var fo = try await fetchFO(vfo: vfo)
        fo[1] = String(format: "%010llu", hz)
        try await pushFO(fo)
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let fo = try await fetchFO(vfo: vfo)
        guard fo.count >= 2, let freq = UInt64(fo[1]) else {
            throw RigError.invalidResponse
        }
        return freq
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let modeIndex = try Self.modeToTMD710Index(mode)
        var fo = try await fetchFO(vfo: vfo)
        guard fo.count >= 13 else { throw RigError.invalidResponse }
        fo[12] = "\(modeIndex)"
        try await pushFO(fo)
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let fo = try await fetchFO(vfo: vfo)
        guard fo.count >= 13, let idx = Int(fo[12]) else {
            throw RigError.invalidResponse
        }
        return try Self.tmd710IndexToMode(idx)
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        try await sendCommand(enabled ? "TX" : "RX")
        // TX/RX do not echo on TM-family per Hamlib
        // tmd710_set_ptt (line ~2367).
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    public func getPTT() async throws -> Bool {
        // TM-family has no CAT query for TX state. Return false
        // conservatively — matches THD72Protocol behavior.
        return false
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        // VFO selection on the TM family is embedded in the FO
        // command's vfo field, not a separate command. Fetching a
        // freq / mode / etc. with a specific `vfo:` argument
        // already routes to the correct VFO. selectVFO is therefore
        // a no-op on this family — front-panel VFO switching is
        // the intended workflow when the operator wants the radio
        // to *display* a different VFO.
    }

    // MARK: - Signal strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Hamlib maps this to the SM command. Response format is
        // "SM 0,<s-meter>\r" with s-meter as 2-digit decimal.
        try await sendCommand("SM 0")
        let response = try await receiveResponse()

        let parts = response.split(separator: ",")
        guard parts.count >= 2, let s = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            throw RigError.invalidResponse
        }
        return SignalStrength(sUnits: min(9, s), raw: s)
    }

    // MARK: - Wire helpers

    /// Fetches the current FO state for the given VFO and returns
    /// its 13 comma-separated fields.
    private func fetchFO(vfo: VFO) async throws -> [String] {
        let vfoIndex = (vfo == .b || vfo == .sub) ? "1" : "0"
        try await sendCommand("FO \(vfoIndex)")
        let response = try await receiveResponse()
        return try parseFO(response)
    }

    /// Writes back a mutated FO state. Consumes the echo.
    private func pushFO(_ fields: [String]) async throws {
        guard fields.count == 13 else {
            throw RigError.invalidResponse
        }
        // Reassemble command exactly as `tmd710_push_fo()` snprintf
        // does — VFO as 1d, freq as 10d, etc. The `fields` array
        // already has the correctly-formatted strings from
        // `parseFO` (they came off the wire in canonical form),
        // so we just join.
        let body = fields.joined(separator: ",")
        try await sendCommand("FO \(body)")
        _ = try await receiveResponse()
    }

    /// Parses a response like `FO 0,0146000000,0,0,0,0,0,0,00,00,000,00000000,0`
    /// into its 13 fields (the leading `FO ` is stripped).
    private func parseFO(_ response: String) throws -> [String] {
        guard response.hasPrefix("FO ") else {
            throw RigError.invalidResponse
        }
        let body = String(response.dropFirst(3))
        let parts = body.split(separator: ",").map(String.init)
        guard parts.count == 13 else {
            throw RigError.invalidResponse
        }
        return parts
    }

    private func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        data.append(Self.terminator)
        try await transport.write(data)
    }

    private func receiveResponse() async throws -> String {
        let data = try await transport.readUntil(
            terminator: Self.terminator,
            timeout: responseTimeout
        )
        var responseData = data
        if responseData.last == Self.terminator {
            responseData.removeLast()
        }
        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }
        return response
    }

    // MARK: - Mode encoding

    /// Cross-checked against Hamlib `rigs/kenwood/tmd710.c` mode
    /// mapping: FM=0, FMN=1, AM=2. Matches TH-D72 by coincidence.
    internal static func modeToTMD710Index(_ mode: Mode) throws -> Int {
        switch mode {
        case .fm:  return 0
        case .fmN: return 1
        case .am:  return 2
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by TM-D710 / TM-V71"
            )
        }
    }

    internal static func tmd710IndexToMode(_ index: Int) throws -> Mode {
        switch index {
        case 0: return .fm
        case 1: return .fmN
        case 2: return .am
        default: throw RigError.invalidResponse
        }
    }
}
