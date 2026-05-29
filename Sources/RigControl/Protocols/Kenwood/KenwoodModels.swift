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

    /// Kenwood TH-D74A tri-band handheld with D-STAR and APRS
    public static let thd74 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D74",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thd74,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thd74
            )
        }
    )

    /// Kenwood TH-D75A tri-band handheld with D-STAR and APRS
    /// (2023 successor to the TH-D74). CAT command set is
    /// backward-compatible with the TH-D74, so we reuse
    /// `KenwoodProtocol`.
    public static let thd75 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D75",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Kenwood.thd75,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.thd75
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
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Kenwood.ts570S
            )
        }
    )
}
