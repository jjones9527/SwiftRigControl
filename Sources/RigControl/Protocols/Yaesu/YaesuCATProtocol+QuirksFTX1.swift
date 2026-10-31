import Foundation

// The FTX-1 quirks preset, split from YaesuCATProtocol+Quirks.swift to
// keep that file under the 500-line soft cap.

extension YaesuCATProtocol.Quirks {
    /// FTX-1 (2025) — full `ST` support, `FT2;` / `FT3;` VFO
    /// selection, plus FTX-1-specific mode codes and a memory-
    /// mode escape prelude requirement.
    ///
    /// Mode codes per `rigs/yaesu/ftx1/ftx1_mode.c` differ from
    /// the shared newcat table on codes 3 and 7:
    /// - Shared newcat: 3 = CW, 7 = CW-R
    /// - FTX-1:         3 = CW-USB, 7 = CW-LSB
    ///
    /// The current Hamlib newcat conversion table also exposes
    /// `A` (DATA-FM), `D` (AM-N), `E` (C4FM), and `F`
    /// (DATA-FM-N). Although an older comment in `ftx1_mode.c`
    /// labels `E` as PSK, Hamlib's executable table and the
    /// FTX-1 capability mask both identify it as C4FM; this
    /// implementation follows that authoritative behavior.
    ///
    /// Memory-mode escape: the FTX-1's `MD` set is silently
    /// treated as a transient overlay when Main is in Memory
    /// mode. Setting `requiresMemoryModeEscape = true` triggers
    /// an `SV0;` prelude (VFO mode restore) before each `MD` /
    /// `FA` / `FB` set — matches Hamlib's `ftx1_ensure_vfo_mode()`
    /// behavior in `ftx1_mode.c` and `ftx1_freq.c`.
    public static let ftx1 = YaesuCATProtocol.Quirks(
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
            .dataFM:   "A",
            .fmN:      "B",
            .dataUSB:  "C",
            .amN:      "D",
            .c4fm:     "E",
            .dataFMN:  "F",
        ],
        requiresMemoryModeEscape: true,
        filterCommandStyle: .doubleZero,  // Hamlib newcat.c:9214
        // FTX-1 exposes RIG_TARGETABLE_ALL per rigs/yaesu/ftx1/ftx1.c,
        // which includes RIG_TARGETABLE_MODE.
        hasTargetableMode: true,
        usesFTX1ClarifierCommands: true
    ).withFunctionForms(cwMessageStyle: .ftx1)
}
