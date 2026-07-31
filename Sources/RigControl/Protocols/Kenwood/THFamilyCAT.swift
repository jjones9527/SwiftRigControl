import Foundation

/// Actor implementing the Kenwood TH-F-family CAT protocol.
///
/// Covers the TH-F6A (tri-band 2m + 1.25m + 70cm) and TH-F7E
/// (European dual-band 2m + 70cm) portable handhelds. Both share
/// Hamlib's `rigs/kenwood/th.c` shared helpers, invoked from
/// `thf6a.c` / `thf7.c` per-radio caps structs.
///
/// Distinct from ``THD72Protocol`` and ``TMFamilyCAT``:
///
/// - **`FQ` command for frequency**, not `FO` — the TH-F family
///   doesn't pack radio state into an omnibus response. Instead
///   each state item has its own tiny read/write command.
/// - **Separate `MD` command for mode**, not embedded in the
///   frequency response.
/// - No dedicated VFO-selection command over CAT (VFO is
///   front-panel-controlled).
///
/// ## FQ command format
///
/// Per Hamlib `rigs/kenwood/th.c` `th_set_freq()`:
///
/// ```text
/// FQ <freq(11-digit)>,<step(1-2 hex)><CR>
/// ```
///
/// - `freq` — 11 digits in Hz, zero-padded (`%011lld`).
/// - `step` — variable-length hex (tuning step index, `%X`).
///
/// The radio echoes an `OK\r` on success. Read format:
///
/// ```text
/// FQ <freq>,<step>
/// ```
///
/// ## MD command format
///
/// Per Hamlib `th_set_mode()`:
///
/// ```text
/// MD <mode-index>
/// ```
///
/// TH-F6A mode indices per `thf6a.c` `thf6_mode_table`:
/// 0=FM, 1=WFM, 2=AM, 3=LSB, 4=USB, 5=CW.
///
/// TX is FM-only per `THF6_MODES_TX`. Non-FM modes are RX-only.
public actor THFamilyCAT:
    CATProtocol,
    SupportsSignalStrength
{

    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    private let responseTimeout: TimeInterval = 2.0

    /// CR terminator (EOM_TH in Hamlib).
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
        // Format matches Hamlib `th_set_freq()` at
        // `rigs/kenwood/th.c:209-241`:
        //   FQ %011lld,%X
        //
        // The step field is not a persistent user setting to
        // preserve — Hamlib computes it from the frequency on
        // every set. See `computeStepAndRoundedFreq(hz:)` for the
        // algorithm; the short version is: pick the 5-kHz grid
        // (step 0) or 6.25-kHz grid (step 1) that gives the
        // smaller error, and override to the 10-kHz grid (step 4)
        // above 470 MHz.
        //
        // Prior to the v1.2.4 fix this method snapshotted the
        // step from the last `getFrequency` call and reused it on
        // every subsequent set — which meant a fresh actor (no
        // prior get) always sent step 0, wrong for VHF/UHF
        // above 470 MHz.
        let (freqSent, step) = Self.computeStepAndRoundedFreq(hz: hz)
        let stepHex = String(step, radix: 16, uppercase: true)
        let command = String(format: "FQ %011llu,%@", freqSent, stepHex)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        try await sendCommand("FQ")
        let response = try await receiveResponse()

        // Response format: FQ <freq>,<step>
        // The step field is discarded — Hamlib does the same at
        // `th.c:250-282`, and it is recomputed on every set. Keeping
        // it locally would just mask a stale-cache bug the next
        // time the front panel changed the grid.
        guard response.hasPrefix("FQ ") else {
            throw RigError.invalidResponse
        }
        let body = String(response.dropFirst(3))
        let parts = body.split(separator: ",")
        guard parts.count >= 2,
              let freq = UInt64(parts[0]) else {
            throw RigError.invalidResponse
        }
        return freq
    }

    /// Reproduces Hamlib's `th_set_freq()` step / freq computation
    /// (`rigs/kenwood/th.c:220-240`).
    ///
    /// Returns the rounded frequency to send on the wire and the
    /// step index that pairs with it. `internal` so the tests can
    /// assert per-grid boundary behavior without going through the
    /// transport.
    ///
    /// The algorithm:
    /// 1. Round `hz` to the nearest 5 kHz and 6.25 kHz grid.
    /// 2. Pick whichever grid gives the smaller error. Step is
    ///    `0` for the 5-kHz grid, `1` for the 6.25-kHz grid.
    /// 3. If the chosen freq is ≥ 470 MHz, override to the
    ///    10-kHz grid (step `4` in the TH-F6A `.tuning_steps`
    ///    table — see `rigs/kenwood/thf6a.c:210-222`).
    internal static func computeStepAndRoundedFreq(hz: UInt64) -> (freq: UInt64, step: UInt8) {
        let freqDouble = Double(hz)
        let freq5 = (freqDouble / 5000.0).rounded() * 5000.0
        let freq625 = (freqDouble / 6250.0).rounded() * 6250.0
        let step: UInt8
        var freqSent: Double
        if abs(freq5 - freqDouble) < abs(freq625 - freqDouble) {
            step = 0
            freqSent = freq5
        } else {
            step = 1
            freqSent = freq625
        }
        if freqSent >= 470_000_000 {
            freqSent = (freqSent / 10_000.0).rounded() * 10_000.0
            return (UInt64(freqSent), 4)
        }
        return (UInt64(freqSent), step)
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let idx = try Self.modeToTHFIndex(mode)
        try await sendCommand("MD \(idx)")
        _ = try await receiveResponse()
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try await sendCommand("MD")
        let response = try await receiveResponse()

        // Response format: MD <index>
        guard response.hasPrefix("MD ") else {
            throw RigError.invalidResponse
        }
        let payload = response.dropFirst(3).trimmingCharacters(in: .whitespaces)
        guard let idx = Int(payload) else {
            throw RigError.invalidResponse
        }
        return try Self.thfIndexToMode(idx)
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        try await sendCommand(enabled ? "TX" : "RX")
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    public func getPTT() async throws -> Bool {
        // TH-F family has no CAT query for TX state. Return false
        // conservatively.
        return false
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        // TH-F6A / TH-F7E do not expose VFO selection through CAT
        // in a way that's reliable across firmware versions.
        // Front-panel-only.
    }

    // MARK: - Signal strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Per Hamlib th.c: SM 0 → response "SM 0,<value>\r".
        try await sendCommand("SM 0")
        let response = try await receiveResponse()
        let parts = response.split(separator: ",")
        guard parts.count >= 2,
              let s = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            throw RigError.invalidResponse
        }
        return SignalStrength(sUnits: min(9, s), raw: s)
    }

    // MARK: - Wire helpers

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

    /// Cross-checked against `thf6a.c` `thf6_mode_table` (also used
    /// by TH-F7E). Only FM is TX-capable per `THF6_MODES_TX` — the
    /// caller is responsible for enforcing the RX-only constraint
    /// on non-FM modes if desired.
    internal static func modeToTHFIndex(_ mode: Mode) throws -> Int {
        switch mode {
        case .fm:  return 0
        case .wfm: return 1
        case .am:  return 2
        case .lsb: return 3
        case .usb: return 4
        case .cw:  return 5
        default:
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by TH-F6A / TH-F7E"
            )
        }
    }

    internal static func thfIndexToMode(_ index: Int) throws -> Mode {
        switch index {
        case 0: return .fm
        case 1: return .wfm
        case 2: return .am
        case 3: return .lsb
        case 4: return .usb
        case 5: return .cw
        default: throw RigError.invalidResponse
        }
    }
}
