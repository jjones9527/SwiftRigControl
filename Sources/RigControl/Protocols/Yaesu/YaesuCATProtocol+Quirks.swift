import Foundation

// Per-model behavioural quirks for the Yaesu newcat command family.
//
// Extracted from `YaesuCATProtocol.swift` in the v1.2.4 structural
// refactor — the struct plus its presets grew to ~320 lines
// through the v1.2.0-v1.2.3 wire-format audit and dominated the
// actor file. Splitting it here keeps `YaesuCATProtocol.swift`
// under the 500-line soft cap and gives the quirks their own
// documented home.

extension YaesuCATProtocol {
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
}
