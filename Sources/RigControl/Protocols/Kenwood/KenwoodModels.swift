import Foundation

/// Pre-defined Kenwood radio models.
extension RadioDefinition.Kenwood {
    /// Kenwood TS-890S HF/6m transceiver
    public static let ts890S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-890S",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts890S,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts890S
            )
        }
    )

    /// Kenwood TS-990S HF/6m transceiver (flagship model)
    public static let ts990S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-990S",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts990S,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts990S
            )
        }
    )

    /// Kenwood TS-590SG HF/6m transceiver
    public static let ts590SG = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-590SG",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts590SG,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts590SG
            )
        }
    )

    // MARK: - Removed in v1.1.0
    //
    // The TM-D710 and TM-V71 factories were removed after real-
    // hardware testing on 2026-05-29 confirmed that
    // `KenwoodProtocol` is structurally incompatible with these
    // radios. See `Documentation/HAMLIB_PARITY.md` (or the v1.2
    // roadmap) for the captured wire bytes and the planned
    // `TMD710Protocol` design.

    /// Kenwood TS-480SAT HF/6m all-mode transceiver
    public static let ts480SAT = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-480SAT",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts480SAT,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts480SAT
            )
        }
    )

    /// Kenwood TS-2000 HF/VHF/UHF all-mode transceiver
    public static let ts2000 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-2000",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts2000,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts2000
            )
        }
    )

    /// Kenwood TS-590S HF/6m transceiver (earlier version of TS-590SG)
    public static let ts590S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-590S",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts590S,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts590S
            )
        }
    )

    /// Kenwood TS-870S HF/6m transceiver (classic flagship)
    public static let ts870S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-870S",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts870S,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts870S
            )
        }
    )

    /// Kenwood TS-480HX HF/6m 200W transceiver
    public static let ts480HX = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-480HX",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts480HX,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts480HX
            )
        }
    )

    /// Kenwood TH-D74A tri-band handheld with D-STAR and APRS.
    ///
    /// Uses ``THD72Protocol`` with ``THD72Protocol/Family/thd74`` —
    /// the TH-D74 shares the TH-D72's CR-terminated FO-string
    /// protocol but its FO response is 72 bytes (not 53) with the
    /// mode selector at character 31 (not 51). Prior to v1.2.0 this
    /// factory shipped wired to `KenwoodProtocol` (semicolon-
    /// terminated), which cannot drive a real TH-D74 — that was a
    /// latent bug hidden because no TH-D74 was hardware-verified.
    /// Cross-checked against Hamlib `rigs/kenwood/thd74.c`
    /// (`.cmdtrm = EOM_TH`, lines 274 + 537).
    public static let thd74 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D74",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thd74,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            THD72Protocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thd74,
                family: .thd74
            )
        }
    )

    /// Kenwood TH-D75A tri-band handheld with D-STAR and APRS
    /// (2023 successor to the TH-D74).
    ///
    /// TH-D75 does not exist in Hamlib as of 4.7.2, but Kenwood's
    /// service documentation states the CAT command set is
    /// backward-compatible with the TH-D74. Uses ``THD72Protocol``
    /// with ``THD72Protocol/Family/thd74`` accordingly. Same latent-
    /// bug story as TH-D74: prior to v1.2.0 this factory shipped
    /// wired to `KenwoodProtocol` (semicolon-terminated), which
    /// cannot drive a TH-D74-family radio.
    public static let thd75 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D75",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thd75,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            THD72Protocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thd75,
                family: .thd74
            )
        }
    )

    /// Kenwood TH-D72A dual-band handheld with APRS and GPS
    ///
    /// Uses THD72Protocol (CR-terminated, FO-string based) rather than the
    /// standard semicolon Kenwood CAT used by HF transceivers.
    public static let thd72A = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D72A",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thd72A,
        verificationStatus: .hardware,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            THD72Protocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thd72A
            )
        }
    )

    /// Kenwood TH-D72 dual-band handheld with APRS and GPS (non-A variant)
    ///
    /// Identical protocol and capabilities to the TH-D72A. The A suffix denotes
    /// the North American market version; the protocol command set is the same.
    public static let thd72 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D72",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thd72A,
        verificationStatus: .hardware,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            THD72Protocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thd72A
            )
        }
    )

    // MARK: - Legacy HF Radios

    /// Kenwood TS-850S HF 100W transceiver with internal ATU
    ///
    /// Default baud rate is 1200 — significantly lower than modern Kenwood radios.
    public static let ts850S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-850S",
        defaultBaudRate: 1200,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts850S,
        serialDefaults: .kenwoodLegacy,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts850S
            )
        }
    )

    /// Kenwood TS-570D HF/6m 100W transceiver with ATU and DSP
    ///
    /// Default baud rate is 4800. Includes 6m coverage (unlike the TS-570S).
    public static let ts570D = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-570D",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts570D,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts570D
            )
        }
    )

    /// Kenwood TS-570S HF-only 100W transceiver with DSP (no 6m, no ATU)
    ///
    /// Default baud rate is 4800. Budget sibling of the TS-570D — HF bands only.
    public static let ts570S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-570S",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts570S,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts570S
            )
        }
    )

    // MARK: - v1.2.0 Group G — legacy HF still on the air

    /// Kenwood TS-450S — HF 100W transceiver (1991).
    ///
    /// HF-only sibling of the TS-690S. Cross-checked against
    /// Hamlib `rigs/kenwood/ts450s.c` — 4800 baud maximum, 8-N-2,
    /// hardware handshake.
    public static let ts450S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-450S",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts450S,
        serialDefaults: .kenwoodLegacy,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts450S
            )
        }
    )

    /// Kenwood TS-690S — HF + 6m 100W transceiver (1992).
    ///
    /// TS-450S with 6m added. Cross-checked against Hamlib
    /// `rigs/kenwood/ts690.c` — 4800 baud, 8-N-2, hardware
    /// handshake (same profile as TS-450S / TS-940S / TS-850S).
    public static let ts690S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-690S",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts690S,
        serialDefaults: .kenwoodLegacy,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts690S
            )
        }
    )

    /// Kenwood TS-940S — HF 100W flagship transceiver (1985).
    ///
    /// Kenwood's mid-1980s flagship. Cross-checked against Hamlib
    /// `rigs/kenwood/ts940.c` — 4800 baud, 8-N-2, hardware
    /// handshake. Note the model name is "TS-940S" (with S suffix)
    /// even though Hamlib's `RIG_MODEL_TS940` enum drops it.
    public static let ts940S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-940S",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts940S,
        serialDefaults: .kenwoodLegacy,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts940S
            )
        }
    )

    /// Kenwood TS-950S — HF 150W flagship transceiver (1988).
    ///
    /// Cross-checked against Hamlib `rigs/kenwood/ts950.c`. Uses
    /// the unusual `kenwoodLegacyNoHandshake` serial profile
    /// (8-N-2, no flow control) — the TS-950S is the only radio
    /// in this era's Kenwood catalog that drops hardware handshake
    /// while keeping the 8-N-2 framing.
    public static let ts950S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-950S",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts950S,
        serialDefaults: .kenwoodLegacyNoHandshake,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts950S
            )
        }
    )

    /// Kenwood TS-950SDX — DSP-equipped variant of TS-950S (1991).
    ///
    /// Same 150 W flagship as TS-950S, with internal DSP filtering.
    /// Cross-checked against Hamlib `rigs/kenwood/ts950.c`
    /// (`ts950sdx_caps`). Same serial framing as TS-950S.
    public static let ts950SDX = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-950SDX",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Kenwood.ts950SDX,
        serialDefaults: .kenwoodLegacyNoHandshake,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts950SDX
            )
        }
    )

    // MARK: - v1.2.0 Group E — CR-terminated TH/TM CAT

    /// Kenwood TM-D710(G) — dual-band FM mobile transceiver.
    ///
    /// Uses ``TMFamilyCAT`` — the TM-family radios use a
    /// comma-separated `FO` command with 13 fields per Hamlib
    /// `rigs/kenwood/tmd710.c`. Different from the TH-D72's
    /// fixed-position FO layout, so its own protocol type.
    public static let tmD710 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TM-D710(G)",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.tmd710,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            TMFamilyCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.tmd710
            )
        }
    )

    /// Kenwood TM-V71(A) — dual-band FM mobile transceiver.
    ///
    /// Same wire protocol as TM-D710 per Hamlib `rigs/kenwood/tmd710.c`
    /// (both models share the same source file). Minus the D-STAR /
    /// TNC hardware, otherwise identical.
    public static let tmV71 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TM-V71(A)",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.tmv71,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            TMFamilyCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.tmv71
            )
        }
    )

    /// Kenwood TH-F6A — tri-band FM/SSB HT (2m + 1.25m + 70cm).
    ///
    /// Uses ``THFamilyCAT`` — the TH-F family uses discrete
    /// per-item commands (`FQ` for frequency, `MD` for mode) rather
    /// than the omnibus FO string TH-D72 / TM-D710 use. Cross-checked
    /// against Hamlib `rigs/kenwood/thf6a.c` + shared `th.c` helpers.
    public static let thF6A = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-F6A",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thf6a,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            THFamilyCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thf6a
            )
        }
    )

    /// Kenwood TH-F7E — European dual-band variant of TH-F6A.
    ///
    /// Same wire protocol as TH-F6A per Hamlib `rigs/kenwood/thf7.c`
    /// (both share `th.c` helpers). 2m + 70cm TX only.
    public static let thF7E = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-F7E",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thf7e,
        serialDefaults: .kenwoodDesktop,
        protocolFactory: { transport in
            THFamilyCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thf7e
            )
        }
    )
}
