import Foundation

/// Actor implementing the Yaesu CAT protocol for radio control.
///
/// Modern Yaesu radios (FTDX-10, FT-991A, FT-710, FT-891, etc.) use a text-based
/// CAT protocol that is compatible with Kenwood's protocol. Commands are ASCII
/// text terminated with semicolons.
///
/// Example commands:
/// - `FA14230000;` - Set VFO A to 14.230 MHz
/// - `MD2;` - Set mode to USB
/// - `TX1;` - PTT on
public actor YaesuCATProtocol:
    CATProtocol,
    SupportsPower,
    SupportsSplit,
    SupportsSignalStrength,
    SupportsRIT,
    SupportsXIT,
    SupportsAGC,
    SupportsNoiseBlanker,
    SupportsNoiseReduction,
    SupportsIFFilter,
    SupportsAFGain,
    SupportsRFGain,
    SupportsSquelch,
    SupportsPreamp,
    SupportsAttenuator,
    SupportsRemotePowerState,
    SupportsMemoryChannels,
    SupportsVFOOperations,
    SupportsFunctions,
    SupportsMicGain,
    SupportsCompressorLevel,
    SupportsMonitorGain,
    SupportsVOXGain,
    SupportsVOXDelay,
    SupportsIFShift
{
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Per-model behavioural quirks that the shared newcat command
    /// set can't express on its own — things like whether the radio
    /// supports the `ST` split command or which numeric parameters
    /// its `FT` VFO-selection command expects.
    public let quirks: Quirks

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Command terminator (semicolon)
    private static let terminator: UInt8 = 0x3B  // ';'

    /// Per-model behavioural quirks.
    ///
    /// The Yaesu newcat command family is *mostly* uniform across
    /// modern HF radios, but the `ST` (split) and `FT` (TX VFO
    /// selection) commands diverge across models. This struct
    /// captures the differences without leaking Yaesu-specifics
    /// into the shared `RigCapabilities` type.
    ///
    /// Sourced from Hamlib `rigs/yaesu/newcat.c` — the
    /// `valid_commands` table (which model supports which command)
    /// and the model-specific branches inside `newcat_set_split_vfo`
    /// / `newcat_set_tx_vfo`.
    public struct Quirks: Sendable {
        /// `true` when the radio supports the `ST0;` / `ST1;` split
        /// command. FTDX-10, FT-DX101(D/MP), FT-710, FT-450 — but
        /// FT-450's `ST` means Step, not Split, so Hamlib excludes
        /// it there. See `newcat.c:578` and the exclusion at
        /// `newcat.c:8327`.
        public let supportsSTSplit: Bool

        /// `true` when the radio's `FT` command uses the `FT2;` /
        /// `FT3;` numeric encoding for VFO A/B (with `FT0;`/`FT1;`
        /// reserved for toggling the TX function). Applies to
        /// FT-950, FT-2000, FT-DX3000/5000/1200, FT-991(A),
        /// FTDX-10, FT-DX101(D/MP). Other radios use the classic
        /// `FT0;`/`FT1;` for A/B. See `newcat.c:8216-8222`.
        public let usesFT23ForVFOSelection: Bool

        /// `true` when the radio's `FT` command exists at all. The
        /// FT-891 is the only known modern Yaesu HF radio that has
        /// no `FT` command per `newcat.c:516`. Without `FT`, split
        /// operation cannot be established via the newcat protocol.
        public let supportsFTVFOSelection: Bool

        /// Number of decimal digits the radio's `FA` / `FB` frequency
        /// commands expect on the wire. Modern newcat radios use 9
        /// (FT-DX10 / FT-DX101 / FT-991A / FT-710 / FTX-1). Older
        /// newcat radios (identifiable by a 27- or 30-byte `IF`
        /// response per `newcat.c`) use 8. Default is 9.
        ///
        /// Prior to v1.2.0 this was hard-coded to 11, which no real
        /// Yaesu radio actually accepts — a latent bug affecting
        /// every newcat radio in the catalog. See the v1.2.0
        /// CHANGELOG for the fix.
        public let frequencyDigits: Int

        /// FTX-1-specific mode selector table, or `nil` to use the
        /// shared newcat `MD` table (`1=LSB, 2=USB, 3=CW-USB, 4=FM,
        /// 5=AM, 6=RTTY-LSB, 7=CW-LSB, 8=DATA-LSB, 9=RTTY-USB,
        /// A=DATA-FM, B=FM-N, C=DATA-USB, D=AM-N` — the FTX-1 table
        /// per `rigs/yaesu/ftx1/ftx1_mode.c` file header).
        ///
        /// The FTX-1 differs from the shared newcat table on codes
        /// 3 (CW-USB vs CW), 7 (CW-LSB vs CW-R), and adds C4FM entries
        /// (H, I) plus a PSK entry (E). Radios that use the shared
        /// table can leave this `nil`.
        public let modeCodeTable: [Mode: Character]?

        /// When `true`, `setMode` / `setFrequency` should send an
        /// `SV;` (or equivalent) prelude to force the radio out of
        /// Memory mode before the actual set command. Required by
        /// the FTX-1 per Hamlib `rigs/yaesu/ftx1/ftx1_mode.c`
        /// ("Memory-mode MD sets on Main are accepted but do not
        /// persist — they act as a transient memory-tune overlay").
        public let requiresMemoryModeEscape: Bool

        /// Per-family `SH` (IF filter / bandwidth) wire format. Yaesu
        /// newcat has four incompatible SH variants across the family
        /// per Hamlib `rigs/yaesu/newcat.c:9202-9220`. Defaults to
        /// ``SHCommandStyle/qualifierOnly`` — the form used by
        /// FT-950 / FT-991 / FT-991A / FTDX-5000 / FTDX-1200 /
        /// FTDX-9000 / FT-450(D).
        public let filterCommandStyle: SHCommandStyle

        /// `true` when the radio implements `RIG_TARGETABLE_MODE` per
        /// Hamlib — meaning the `MD` command's qualifier byte
        /// selects VFO A (`0`) or VFO B (`1`) rather than always
        /// addressing main. Applies to FT-2000, FTDX-5000, FTDX-9000,
        /// FTDX-10, FT-710, FTDX-101D/MP, and FTX-1. On these radios
        /// `setMode(mode, vfo: .b)` emits `MD1<char>;` instead of
        /// `MD0<char>;`.
        ///
        /// On non-targetable radios (FT-950, FT-991/A, FTDX-3000,
        /// FTDX-1200, FT-450(D), FT-891) the qualifier is always `0`
        /// and the `vfo` argument to `setMode` / `getMode` is
        /// ignored on the wire — the front-panel VFO selection
        /// dictates which VFO the mode change lands on.
        ///
        /// Cross-checked against `.targetable_vfo` in each Hamlib
        /// backend (`rigs/yaesu/*.c`); see `newcat.c:1797-1800`
        /// (set) and `newcat.c:1879-1882` (get) for the dispatch.
        public let hasTargetableMode: Bool

        /// `SH` command wire format.
        ///
        /// Every value cites the Hamlib line where the format is
        /// emitted in `rigs/yaesu/newcat.c::newcat_set_rx_bandwidth`.
        /// Get-side format is inferred from the same file's
        /// `newcat_get_rx_bandwidth` (lines 9477-9486).
        public enum SHCommandStyle: Sendable, Equatable {
            /// `SH%c%02d;` set / `SH%c;` get, where `%c` is `0`
            /// (main) or `1` (sub). The default form — matches
            /// FT-950 / FT-991 / FT-991A / FTDX-5000 / FTDX-1200 /
            /// FTDX-9000 / FT-450(D). Hamlib `newcat.c:9218`.
            case qualifierOnly
            /// `SH0%02d;` set / `SH0;` get. VFO qualifier is always
            /// `0`, no separate `%c` byte. FT-2000 / FTDX-3000.
            /// Hamlib `newcat.c:9210` and `newcat.c:9481`.
            case zeroWithoutQualifier
            /// `SH00%02d;` set / `SH0;` get. Literal double-zero
            /// prefix. FTDX-10 / FT-710 / FTX-1. Hamlib
            /// `newcat.c:9214` (set) and `newcat.c:9481` (get; note
            /// FTX-1 falls through to the qualifier get form — see
            /// implementation note in ``setIFFilter``).
            case doubleZero
            /// `SH%c%d%02d;` set / `SH%c;` get, where the second
            /// digit is the "bandwidth on" flag. FT-DX101D/MP send
            /// the actual on-state; FT-891 always sends `1`.
            /// Hamlib `newcat.c:9205-9207`.
            case vfoAndNarrow(narrowAlwaysOn: Bool)
        }

        public init(
            supportsSTSplit: Bool = false,
            usesFT23ForVFOSelection: Bool = false,
            supportsFTVFOSelection: Bool = true,
            frequencyDigits: Int = 9,
            modeCodeTable: [Mode: Character]? = nil,
            requiresMemoryModeEscape: Bool = false,
            filterCommandStyle: SHCommandStyle = .qualifierOnly,
            hasTargetableMode: Bool = false
        ) {
            self.supportsSTSplit = supportsSTSplit
            self.usesFT23ForVFOSelection = usesFT23ForVFOSelection
            self.supportsFTVFOSelection = supportsFTVFOSelection
            self.frequencyDigits = frequencyDigits
            self.modeCodeTable = modeCodeTable
            self.requiresMemoryModeEscape = requiresMemoryModeEscape
            self.filterCommandStyle = filterCommandStyle
            self.hasTargetableMode = hasTargetableMode
        }

        /// Portable / mobile radios (FT-817/818/857/897/847/920/100/
        /// 1000MP): pre-newcat binary CAT — this shared newcat
        /// implementation does not drive them anyway, but for the
        /// factories that reference this struct we default to the
        /// classic (non-newcat) semantics.
        public static let classic = Quirks()

        /// FT-950, FT-DX5000/1200, FT-991, FT-991A, FTDX-9000 —
        /// no `ST` command, `FT` uses 2/3 for VFO A/B, `SH%c%02d;`
        /// filter format. Split is not a first-class state on these
        /// radios; operators drive split by explicitly selecting TX
        /// VFO.
        ///
        /// FT-2000 and FTDX-3000 belong to a different SH family
        /// (`SH0%02d;`) — use ``ft2000Family`` for those.
        public static let newcatNoST = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true,
            filterCommandStyle: .qualifierOnly
        )

        /// FT-2000 / FTDX-3000 — same `ST` / `FT` behavior as
        /// ``newcatNoST`` but the SH (IF filter / bandwidth) command
        /// uses the `SH0%02d;` form (no VFO byte, just a fixed
        /// zero). Hamlib `newcat.c:9210`, `newcat.c:9481`.
        public static let ft2000Family = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true,
            filterCommandStyle: .zeroWithoutQualifier
        )

        /// FT-DX10, FT-DX101D, FT-DX101MP — full `ST` support and
        /// `FT` uses 2/3 for VFO selection. Prefer the family-
        /// specific presets ``ftdx10Family`` and ``ftdx101Family``
        /// where possible: FTDX-10 uses `SH00%02d;` while the
        /// FTDX-101 pair uses `SH%c%d%02d;` (VFO + narrow flag).
        /// This preset defaults to the ``SHCommandStyle/qualifierOnly``
        /// form and is retained for source compatibility.
        public static let newcatWithSTDX = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true
        )

        /// FT-DX10 — ST-DX split, `FT` 2/3 VFO, and the double-zero
        /// SH form (`SH00%02d;`). Has RIG_TARGETABLE_MODE. Hamlib
        /// `newcat.c:9214`, `rigs/yaesu/ftdx10.c:.targetable_vfo`.
        public static let ftdx10Family = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true,
            filterCommandStyle: .doubleZero,
            hasTargetableMode: true
        )

        /// FT-DX101D / FT-DX101MP — ST-DX split, `FT` 2/3 VFO, and
        /// the VFO-plus-narrow SH form (`SH%c%d%02d;`). The narrow
        /// flag reflects the actual bandwidth-on state on these
        /// radios (unlike the FT-891 which always sends `1`). Has
        /// RIG_TARGETABLE_MODE. Hamlib `newcat.c:9205-9207`,
        /// `rigs/yaesu/ftdx101.c:.targetable_vfo`.
        ///
        /// **Implementation note:** SwiftRigControl's `IFFilter` API
        /// has three symbolic slots and no separate "bandwidth off"
        /// state, so this preset always emits the flag as `1`. That
        /// matches how flrig and WSJT-X drive DX101 in practice.
        public static let ftdx101Family = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true,
            filterCommandStyle: .vfoAndNarrow(narrowAlwaysOn: false),
            hasTargetableMode: true
        )

        /// FT-710 — supports `ST` split, uses classic `FT0;`/`FT1;`
        /// for VFO A/B selection, and the double-zero SH form
        /// (`SH00%02d;`). Has RIG_TARGETABLE_MODE. Hamlib
        /// `newcat.c:9214`, `rigs/yaesu/ft710.c:.targetable_vfo`.
        public static let ft710 = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: false,
            supportsFTVFOSelection: true,
            filterCommandStyle: .doubleZero,
            hasTargetableMode: true
        )

        /// FT-450 / FT-450D — `ST` means Step, not Split, on this
        /// radio. Hamlib explicitly disables split via `ST`
        /// (`newcat.c:8327`). Fall back to `FT` for VFO selection.
        /// SH uses the default `qualifierOnly` form.
        public static let ft450 = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: false,
            supportsFTVFOSelection: true,
            filterCommandStyle: .qualifierOnly
        )

        /// FT-891 — no `FT` command per `newcat.c:516`. Split via
        /// newcat is not available on this radio; both split and
        /// TX VFO selection must throw `unsupportedOperation`. SH
        /// uses `SH%c%d%02d;` with the narrow flag always `1`
        /// per Hamlib `newcat.c:9207`.
        public static let ft891 = Quirks(
            supportsSTSplit: false,
            usesFT23ForVFOSelection: false,
            supportsFTVFOSelection: false,
            filterCommandStyle: .vfoAndNarrow(narrowAlwaysOn: true)
        )

        /// Returns a copy of this preset with `hasTargetableMode`
        /// overridden. Convenience for factory sites where a
        /// preset shared across models needs per-radio targetable-
        /// mode gating (e.g. `.ft2000Family` is shared by FT-2000
        /// which is targetable and FTDX-3000 which is not).
        public func withTargetableMode(_ enabled: Bool = true) -> Quirks {
            Quirks(
                supportsSTSplit: supportsSTSplit,
                usesFT23ForVFOSelection: usesFT23ForVFOSelection,
                supportsFTVFOSelection: supportsFTVFOSelection,
                frequencyDigits: frequencyDigits,
                modeCodeTable: modeCodeTable,
                requiresMemoryModeEscape: requiresMemoryModeEscape,
                filterCommandStyle: filterCommandStyle,
                hasTargetableMode: enabled
            )
        }

        /// FTX-1 (2025) — full `ST` support, `FT2;` / `FT3;` VFO
        /// selection, plus FTX-1-specific mode codes and a memory-
        /// mode escape prelude requirement.
        ///
        /// Mode codes per `rigs/yaesu/ftx1/ftx1_mode.c` differ from
        /// the shared newcat table on codes 3 and 7:
        /// - Shared newcat: 3 = CW, 7 = CW-R
        /// - FTX-1:         3 = CW-USB, 7 = CW-LSB
        ///
        /// FTX-1 also introduces new mode codes not present in
        /// earlier newcat radios: `E` (PSK), `H` (C4FM-DN),
        /// `I` (C4FM-VW). We map `.cw` → `3` (CW-USB) and
        /// `.cwR` → `7` (CW-LSB) as the most operator-obvious
        /// meaning. C4FM and PSK do not have direct Swift `Mode`
        /// enum equivalents and are omitted from the table.
        ///
        /// Memory-mode escape: the FTX-1's `MD` set is silently
        /// treated as a transient overlay when Main is in Memory
        /// mode. Setting `requiresMemoryModeEscape = true` triggers
        /// an `SV0;` prelude (VFO mode restore) before each `MD` /
        /// `FA` / `FB` set — matches Hamlib's `ftx1_ensure_vfo_mode()`
        /// behavior in `ftx1_mode.c` and `ftx1_freq.c`.
        public static let ftx1 = Quirks(
            supportsSTSplit: true,
            usesFT23ForVFOSelection: true,
            supportsFTVFOSelection: true,
            frequencyDigits: 9,
            modeCodeTable: [
                .lsb:      "1",
                .usb:      "2",
                .cw:       "3",   // CW-USB on FTX-1
                .fm:       "4",
                .am:       "5",
                .rtty:     "6",   // RTTY-LSB
                .cwR:      "7",   // CW-LSB on FTX-1
                .dataLSB:  "8",
                .rttyR:    "9",   // RTTY-USB
                .fmN:      "B",
                .dataUSB:  "C",
            ],
            requiresMemoryModeEscape: true,
            filterCommandStyle: .doubleZero,  // Hamlib newcat.c:9214
            // FTX-1 exposes RIG_TARGETABLE_ALL per rigs/yaesu/ftx1/ftx1.c,
            // which includes RIG_TARGETABLE_MODE.
            hasTargetableMode: true
        )
    }

    /// Initializes a new Yaesu CAT protocol instance.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - capabilities: The capabilities of this radio model
    ///   - quirks: Per-model quirks (defaults to `.classic` for
    ///     source-compatibility with the pre-quirks factory
    ///     signature).
    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities,
        quirks: Quirks = .classic
    ) {
        self.transport = transport
        self.capabilities = capabilities
        self.quirks = quirks
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()

        // Send AI0; to disable auto-info mode (if supported)
        try? await sendCommand("AI0")
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // Some radios (FTX-1) silently ignore FA/FB while Main is in
        // Memory mode. Force a VFO-mode restore first when the quirk
        // is set. See `Quirks.ftx1` for the source citation.
        if quirks.requiresMemoryModeEscape {
            try await sendCommand("SV0")
            _ = try await receiveResponse()
        }

        let prefix: String
        switch vfo {
        case .a, .main:
            prefix = "FA"
        case .b, .sub:
            prefix = "FB"
        }

        // Newcat frequency format is prefix + N-digit decimal Hz.
        // N is 9 for FTX-1 / FT-DX10 / FT-DX101 / FT-991A / FT-710
        // and 8 for older newcat radios (per `newcat.c` IF-response
        // length dispatch). Prior to v1.2.0 this was hard-coded to
        // 11, which no real Yaesu accepts.
        let command = "\(prefix)\(String(format: "%0\(quirks.frequencyDigits)llu", hz))"

        try await sendCommand(command)

        // Yaesu radios echo the command back
        _ = try await receiveResponse()
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let prefix: String
        switch vfo {
        case .a, .main:
            prefix = "FA"
        case .b, .sub:
            prefix = "FB"
        }

        try await sendCommand(prefix)
        let response = try await receiveResponse()

        // Response format: FA<N-digit hex>; where N = quirks.frequencyDigits
        // (9 for modern newcat, 8 for older). Prior to v1.2.0 this
        // was hard-coded to 11 — no real Yaesu response matches
        // that. See CHANGELOG for the fix.
        let digits = quirks.frequencyDigits
        guard response.hasPrefix(prefix),
              response.count >= prefix.count + digits else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: prefix.count)
        let endIndex = response.index(startIndex, offsetBy: digits)
        let freqString = String(response[startIndex..<endIndex])

        guard let freq = UInt64(freqString) else {
            throw RigError.invalidResponse
        }

        return freq
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        // Memory-mode escape prelude (FTX-1 quirk). See setFrequency
        // for the source citation.
        if quirks.requiresMemoryModeEscape {
            try await sendCommand("SV0")
            _ = try await receiveResponse()
        }

        // Radios with a custom mode-code table (FTX-1) look up the
        // character directly; older newcat radios use the shared
        // numeric table.
        let modeCodeChar: Character
        if let table = quirks.modeCodeTable {
            guard let ch = table[mode] else {
                throw RigError.unsupportedOperation(
                    "Mode \(mode.rawValue) not supported by this Yaesu variant"
                )
            }
            modeCodeChar = ch
        } else {
            let numericCode = try modeToYaesuCode(mode)
            modeCodeChar = Character("\(numericCode)")
        }

        // Wire format: `MD0<char>;` (VFO A) or `MD1<char>;` (VFO B).
        // Hamlib `newcat.c:1785, 1797-1800`. On radios without
        // RIG_TARGETABLE_MODE the qualifier is always `0` and the
        // `vfo` argument is ignored on the wire (front-panel
        // selection dictates which VFO the mode change lands on).
        let qualifier = modeQualifierByte(for: vfo)
        let command = "MD\(qualifier)\(modeCodeChar)"

        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        // Wire format: `MD0;` (VFO A) or `MD1;` (VFO B) on
        // targetable radios; `MD0;` universally otherwise. Hamlib
        // `newcat.c:1883-1885`.
        let qualifier = modeQualifierByte(for: vfo)
        try await sendCommand("MD\(qualifier)")
        let response = try await receiveResponse()

        // Response format: `MD<q><char>;` where `<q>` echoes the
        // requested VFO qualifier byte and `<char>` is the mode
        // code. Prior to the v1.2.3 fix the parser expected 3-char
        // `MD<char>;` (no qualifier) which real newcat radios
        // don't emit.
        guard response.hasPrefix("MD"),
              response.count >= 4 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 3)
        let codeChar = response[codeIndex]

        // Custom table lookup (FTX-1) — invert the character table.
        if let table = quirks.modeCodeTable {
            for (mode, ch) in table where ch == codeChar {
                return mode
            }
            throw RigError.invalidResponse
        }

        // Shared numeric table.
        guard let modeCode = Int(String(codeChar)) else {
            throw RigError.invalidResponse
        }

        return try yaesuCodeToMode(modeCode)
    }

    /// The `MD` qualifier byte for the given `vfo` per the current
    /// quirks. Returns `"0"` for VFO A / main and `"1"` for VFO B /
    /// sub, but only respects the caller's VFO argument when the
    /// radio has RIG_TARGETABLE_MODE — on non-targetable radios the
    /// qualifier is always `"0"` per Hamlib `newcat.c:1797-1800`.
    private func modeQualifierByte(for vfo: VFO) -> Character {
        guard quirks.hasTargetableMode else { return "0" }
        return (vfo == .b) ? "1" : "0"
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        // Yaesu uses TX0; for off, TX1; for on (different from Elecraft's TX;/RX;)
        let command = enabled ? "TX1" : "TX0"
        try await sendCommand(command)

        // Yaesu may not echo PTT commands, so just wait briefly
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    public func getPTT() async throws -> Bool {
        // Query TX status. Modern Yaesu radios (FT-950, FTDX-10,
        // FT-991A, etc.) can respond with TX0 (RX), TX1 (TX via
        // front-panel mic), TX2 (TX via rear data jack), or TX3
        // (TX via CAT/USB). Anything non-zero means the radio is
        // transmitting — matches Hamlib `newcat_get_ptt`
        // (rigs/yaesu/newcat.c:2282-2295). The pre-fix code
        // recognised only TX1 and misreported TX2/TX3 as "not
        // transmitting", which could confuse UI state and lead an
        // operator to send another PTT while the radio was already
        // keyed.
        try await sendCommand("TX")
        let response = try await receiveResponse()

        guard response.hasPrefix("TX"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        switch codeChar {
        case "0":                     return false
        case "1", "2", "3":           return true
        default:                      throw RigError.invalidResponse
        }
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        // The Yaesu newcat `FT` command has two encodings depending
        // on the radio family. On FT-950 / FT-2000 / FT-DX3000 /
        // FT-DX5000 / FT-DX1200 / FT-991(A) / FT-DX10 /
        // FT-DX101(D/MP), `FT0;` and `FT1;` *toggle* the TX
        // function, and `FT2;` / `FT3;` select VFO A / B — sending
        // `FT0;` on those radios where the operator meant "select
        // VFO A" would silently toggle TX-VFO assignment instead,
        // which is exactly the class of error the pre-fix code
        // could produce. On radios that use the classic 0/1
        // encoding (FT-710, FT-450), the offset does not apply.
        // FT-891 has no `FT` command at all per Hamlib
        // `newcat.c:516`.
        //
        // Reference: Hamlib `newcat_set_tx_vfo` (newcat.c:8164) and
        // the model-specific offset at newcat.c:8216-8222.
        guard quirks.supportsFTVFOSelection else {
            throw RigError.unsupportedOperation(
                "TX VFO selection via CAT is not supported by this Yaesu radio (FT command unavailable)"
            )
        }

        let digit: Character
        switch vfo {
        case .a, .main:
            digit = quirks.usesFT23ForVFOSelection ? "2" : "0"
        case .b, .sub:
            digit = quirks.usesFT23ForVFOSelection ? "3" : "1"
        }

        try await sendCommand("FT\(digit)")
        _ = try await receiveResponse()
    }

    // MARK: - Power Control

    public func setPower(_ level: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        // Yaesu radios use PowerUnits.watts; `level` is interpreted
        // as watts and converted to the radio's 000–100 percentage protocol.
        let percentage = min(max((level * 100) / capabilities.maxPower, 0), 100)
        let command = String(format: "PC%03d", percentage)

        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        try await sendCommand("PC")
        let response = try await receiveResponse()

        // Response format: PCxxx; where xxx is 000-100
        guard response.hasPrefix("PC"),
              response.count >= 5 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 2)
        let endIndex = response.index(startIndex, offsetBy: 3)
        let percentString = String(response[startIndex..<endIndex])

        guard let percentage = Int(percentString) else {
            throw RigError.invalidResponse
        }

        return (percentage * capabilities.maxPower) / 100
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Yaesu FT-991A and similar use RM5; to read main S-meter
        // Note: Command may vary by model (RM1-RM9 for different meters)
        try await sendCommand("RM5")
        let response = try await receiveResponse()

        // Response format: "RM5nnn" where nnn is 000-255
        guard response.hasPrefix("RM5"),
              response.count >= 6 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 3)
        let endIndex = response.index(startIndex, offsetBy: 3)
        let valueString = String(response[startIndex..<endIndex])

        guard let rawValue = Int(valueString) else {
            throw RigError.invalidResponse
        }

        // Yaesu: 0-255 scale
        // Roughly: 0-120 = S0-S9 (about 13 units per S-unit)
        // 121-255 = S9+1 to S9+60 (about 2 units per dB)
        let sUnits = min(rawValue / 13, 9)
        let overS9 = sUnits >= 9 ? max((rawValue - 117) / 2, 0) : 0

        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
    }

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// Per Hamlib `rigs/yaesu/newcat.c` `newcat_set_rit`:
    /// - `RC;` (clarifier-clear) prelude — clears any accumulated
    ///   offset so the new value is absolute, not relative.
    /// - `RUnnnn;` (positive offset) or `RDnnnn;` (negative offset) —
    ///   4-digit **unsigned** decimal, direction encoded in the
    ///   command letter (`RU` = up / positive, `RD` = down /
    ///   negative). Hamlib uses `%04ld` with `labs()`.
    /// - `RT1;` to enable, `RT0;` to disable.
    ///
    /// Prior to the v1.2.0 audit fix Swift emitted signed 5-digit
    /// values (`RU+0100;`) which real newcat radios reject — the
    /// `+` sign character is not part of the on-wire format.
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled
    ///   and offset in Hz, -9999 to +9999)
    /// - Throws: `RigError` if operation fails
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Clear any accumulated offset before setting a new one.
        try await sendCommand("RC")
        _ = try await receiveResponse()

        // Direction encoded in command letter; value is unsigned.
        let magnitude = abs(state.offset)
        let command: String
        if state.offset >= 0 {
            command = String(format: "RU%04d", magnitude)
        } else {
            command = String(format: "RD%04d", magnitude)
        }

        try await sendCommand(command)
        _ = try await receiveResponse()

        // Set RIT ON/OFF
        let enableCommand = state.enabled ? "RT1" : "RT0"
        try await sendCommand(enableCommand)
        _ = try await receiveResponse()
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset.
    ///
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails
    public func getRIT() async throws -> RITXITState {
        // Read RIT ON/OFF status
        try await sendCommand("RT")
        let enableResponse = try await receiveResponse()

        // Response format: RTx; where x is 0 or 1
        guard enableResponse.hasPrefix("RT"),
              enableResponse.count >= 3 else {
            throw RigError.invalidResponse
        }

        let enableIndex = enableResponse.index(enableResponse.startIndex, offsetBy: 2)
        let enableChar = enableResponse[enableIndex]
        let enabled = enableChar == "1"

        // Read RIT offset
        // Note: Some Yaesu radios may not support reading offset directly
        // In that case, we return 0 as offset
        var offset = 0
        do {
            try await sendCommand("RC")
            let offsetResponse = try await receiveResponse()

            // Response format: RC+nnnnn; or RC-nnnnn;
            guard offsetResponse.hasPrefix("RC"),
                  offsetResponse.count >= 8 else {
                throw RigError.invalidResponse
            }

            let startIndex = offsetResponse.index(offsetResponse.startIndex, offsetBy: 2)
            let endIndex = offsetResponse.index(startIndex, offsetBy: 6)
            let offsetString = String(offsetResponse[startIndex..<endIndex])

            offset = Int(offsetString) ?? 0
        } catch {
            // If RC command not supported, default to 0 offset
            offset = 0
        }

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// Yaesu radios using Kenwood-compatible CAT commands use:
    /// - `XT1;` to enable XIT
    /// - `XT0;` to disable XIT
    /// - Offset is typically shared with RIT
    ///
    /// **Note:** Many Yaesu radios don't support separate XIT control.
    /// They use RIT for both receive and transmit offset.
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or unsupported
    public func setXIT(_ state: RITXITState) async throws {
        // Try to set XIT - many radios don't support this
        let enableCommand = state.enabled ? "XT1" : "XT0"

        do {
            try await sendCommand(enableCommand)
            _ = try await receiveResponse()
        } catch {
            // If XIT command not supported, throw unsupported error
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio - use RIT instead")
        }
    }

    /// Gets the current XIT state.
    ///
    /// **Note:** Many Yaesu radios don't support separate XIT control.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if XIT not supported
    public func getXIT() async throws -> RITXITState {
        // Try to read XIT status
        do {
            try await sendCommand("XT")
            let response = try await receiveResponse()

            // Response format: XTx; where x is 0 or 1
            guard response.hasPrefix("XT"),
                  response.count >= 3 else {
                throw RigError.invalidResponse
            }

            let enableIndex = response.index(response.startIndex, offsetBy: 2)
            let enableChar = response[enableIndex]
            let enabled = enableChar == "1"

            // XIT typically shares offset with RIT on Yaesu radios
            return RITXITState(enabled: enabled, offset: 0)
        } catch {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        // Yaesu's canonical split command is `ST0;` (off) / `ST1;`
        // (on), *not* `FT0;`/`FT1;` — the pre-fix code used `FT`,
        // which is TX-VFO selection. On FT-950/FT-2000/FT-991(A)/
        // FT-DX3000/5000/1200/9000, sending `FT1;` where split was
        // intended would silently reassign the TX VFO instead of
        // enabling split, and could TX on the wrong frequency.
        //
        // Reference: Hamlib `newcat_set_split` (newcat.c:8317).
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        guard quirks.supportsSTSplit else {
            // On radios without `ST` (FT-950/891/991/2000/DX3000
            // etc.), Hamlib establishes split by explicitly
            // selecting the TX VFO via `FT`. That is a semantically
            // different operation (which VFO transmits, rather
            // than an on/off toggle), so surface it explicitly
            // rather than silently doing the wrong thing.
            throw RigError.unsupportedOperation(
                "Split cannot be toggled as a state on this Yaesu radio; use selectVFO() to set the TX VFO explicitly"
            )
        }

        let command = enabled ? "ST1" : "ST0"
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    public func getSplit() async throws -> Bool {
        guard quirks.supportsSTSplit else {
            throw RigError.unsupportedOperation(
                "Split state cannot be read on this Yaesu radio (ST command unavailable)"
            )
        }

        try await sendCommand("ST")
        let response = try await receiveResponse()

        // Response format: STx; where x is 0 (off) or 1 (on)
        guard response.hasPrefix("ST"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        return codeChar == "1"
    }

    // MARK: - Private Methods

    /// Sends a command to the radio.
    func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        // Add terminator (semicolon)
        data.append(YaesuCATProtocol.terminator)

        try await transport.write(data)
    }

    /// Receives a response from the radio.
    func receiveResponse() async throws -> String {
        // Read until semicolon
        let data = try await transport.readUntil(
            terminator: YaesuCATProtocol.terminator,
            timeout: responseTimeout
        )

        // Remove the terminator
        var responseData = data
        if responseData.last == YaesuCATProtocol.terminator {
            responseData.removeLast()
        }

        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }

        return response
    }

    /// Converts a Mode enum to a Yaesu mode code.
    private func modeToYaesuCode(_ mode: Mode) throws -> Int {
        switch mode {
        case .lsb: return 1
        case .usb: return 2
        case .cw: return 3
        case .fm: return 4
        case .am: return 5
        case .rtty: return 6  // FSK
        case .cwR: return 7
        case .dataLSB: return 8  // PKT-LSB
        case .dataUSB: return 9  // PKT-USB (or DATA-USB)
        case .fmN: return 4  // FM (Yaesu doesn't distinguish FM/FM-N in mode code)
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Yaesu protocol")
        }
    }

    /// Converts a Yaesu mode code to a Mode enum.
    private func yaesuCodeToMode(_ code: Int) throws -> Mode {
        switch code {
        case 1: return .lsb
        case 2: return .usb
        case 3: return .cw
        case 4: return .fm
        case 5: return .am
        case 6: return .rtty
        case 7: return .cwR
        case 8: return .dataLSB
        case 9: return .dataUSB
        default:
            throw RigError.invalidResponse
        }
    }
}
