import Foundation

/// Pre-defined Yaesu radio models.
extension RadioDefinition.Yaesu {
    /// Yaesu FTDX-10 HF/6m transceiver
    public static let ftdx10 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-10",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx10,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx10,
                quirks: .ftdx10Family
            )
        }
    )

    /// Yaesu FTX-1 HF/6m transceiver (2025 flagship portable)
    ///
    /// Uses ``YaesuCATProtocol`` with ``YaesuCATProtocol/Quirks/ftx1``
    /// — the FTX-1 speaks semicolon-terminated newcat but with
    /// FTX-1-specific mode codes (3 = CW-USB rather than CW, 7 =
    /// CW-LSB rather than CW-R) and a memory-mode escape prelude
    /// (`SV0;`) before `MD` / `FA` / `FB` set commands so mode /
    /// frequency changes actually persist. See
    /// `Quirks.ftx1` for full source citations against Hamlib
    /// `rigs/yaesu/ftx1/`.
    ///
    /// RF coverage matches the FTDX-10 (HF + 6m, 100 W), so the
    /// FTdx10 capabilities entry is reused rather than duplicated.
    public static let ftx1 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTX-1",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx10,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx10,
                quirks: .ftx1
            )
        }
    )

    /// Yaesu FT-991A HF/VHF/UHF all-mode transceiver
    public static let ft991A = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991A",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft991A,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft991A,
                quirks: .newcatNoST
            )
        }
    )

    /// Yaesu FT-710 AESS HF/6m transceiver
    ///
    /// The FT-710 is the exception in modern Yaesu HF — its CAT
    /// interface uses 8-N-1 without flow control, matching Hamlib
    /// `rigs/yaesu/ft710.c`. Leave it on ``SerialDefaults/standard``.
    public static let ft710 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-710",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft710,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft710,
                quirks: .ft710
            )
        }
    )

    /// Yaesu FT-891 HF/6m all-mode field transceiver
    public static let ft891 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-891",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft891,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft891,
                quirks: .ft891
            )
        }
    )

    /// Yaesu FT-817 ultra-compact portable HF/VHF/UHF transceiver
    ///
    /// Uses ``YaesuPortableCAT`` — the pre-newcat 5-byte binary CAT
    /// (opcode `0x01` for set-freq, `0x03` for get-freq/mode, etc.).
    /// See `YaesuPortableCAT.swift` for the full frame reference.
    public static let ft817 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-817",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft817,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft817
            )
        }
    )

    /// Yaesu FT-DX101D HF/6m transceiver
    public static let ftdx101D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-101D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101D,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101D,
                quirks: .ftdx101Family
            )
        }
    )

    /// Yaesu FTDX-101MP HF/6m 200W flagship transceiver
    public static let ftdx101MP = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-101MP",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101MP,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101MP,
                quirks: .ftdx101Family
            )
        }
    )

    /// Yaesu FT-857D HF/VHF/UHF mobile transceiver
    ///
    /// Uses ``YaesuPortableCAT`` — same pre-newcat 5-byte binary CAT
    /// as the FT-817 (they share Hamlib `rigs/yaesu/ft817.c`).
    public static let ft857D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-857D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft857D,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft857D
            )
        }
    )

    /// Yaesu FT-897D HF/VHF/UHF base/mobile transceiver
    ///
    /// Uses ``YaesuPortableCAT`` — same pre-newcat 5-byte binary CAT
    /// as the FT-817.
    public static let ft897D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-897D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft897D,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft897D
            )
        }
    )

    /// Yaesu FT-450D HF/6m budget transceiver
    public static let ft450D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-450D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft450D,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft450D,
                quirks: .ft450
            )
        }
    )

    /// Yaesu FT-818 portable QRP HF/VHF/UHF transceiver (successor to FT-817)
    ///
    /// Uses ``YaesuPortableCAT`` — the FT-818 is a QRP-refresh of
    /// the FT-817 with identical CAT; both share Hamlib's
    /// `rigs/yaesu/ft817.c` backend.
    public static let ft818 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-818",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft818,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft818
            )
        }
    )

    /// Yaesu FT-2000 HF/6m 100W transceiver
    public static let ft2000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-2000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft2000,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft2000,
                // FT-2000 has RIG_TARGETABLE_MODE per Hamlib
                // `rigs/yaesu/ft2000.c` — FTDX-3000 does not, so
                // override on this factory rather than baking the
                // flag into the shared `.ft2000Family` preset.
                quirks: .ft2000Family.withTargetableMode()
            )
        }
    )

    /// Yaesu FTDX-3000 HF/6m 100W transceiver
    public static let ftdx3000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-3000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx3000,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx3000,
                quirks: .ft2000Family
            )
        }
    )

    /// Yaesu FT-991 HF/VHF/UHF all-mode transceiver (predecessor to FT-991A)
    public static let ft991 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft991,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft991,
                quirks: .newcatNoST
            )
        }
    )

    /// Yaesu FT-950 HF/6m 100W transceiver
    public static let ft950 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-950",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft950,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft950,
                quirks: .newcatNoST
            )
        }
    )

    /// Yaesu FTDX-5000 HF/6m 200W flagship transceiver
    public static let ftdx5000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-5000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx5000,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx5000,
                // FTDX-5000 has RIG_TARGETABLE_MODE per Hamlib
                // `rigs/yaesu/ft5000.c`.
                quirks: .newcatNoST.withTargetableMode()
            )
        }
    )

    /// Yaesu FTDX-1200 HF/6m 100W transceiver
    public static let ftdx1200 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-1200",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx1200,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx1200,
                quirks: .newcatNoST
            )
        }
    )

    /// Yaesu FT-100 HF/VHF/UHF mobile transceiver
    ///
    /// Uses ``YaesuPortableCAT`` — the same 5-byte binary CAT as
    /// the FT-817 family (per Hamlib `rigs/yaesu/ft817.c`).
    public static let ft100 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-100",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft100,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft100
            )
        }
    )

    /// Yaesu FTDX-9000 series HF/6m flagship transceiver (200W/400W)
    public static let ftdx9000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-9000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx9000,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx9000,
                // FTDX-9000 has RIG_TARGETABLE_MODE per Hamlib
                // `rigs/yaesu/ft9000.c`.
                quirks: .newcatNoST.withTargetableMode()
            )
        }
    )

    /// Yaesu FT-847 HF/VHF/UHF all-band satellite transceiver
    ///
    /// Uses ``YaesuFT847CAT`` — the fire-and-forget pre-newcat 5-byte
    /// binary CAT with satellite-mode support (opcodes 0x4E / 0x8E
    /// toggle sat mode; 0x11 / 0x21 for SAT RX / SAT TX freq). Big-
    /// endian BCD frequency encoding per Hamlib `rigs/yaesu/ft847.c`.
    public static let ft847 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-847",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuFT847CAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft847
            )
        }
    )

    /// Yaesu FT-847UNI — FT-847 with the unidirectional CAT wiring
    /// mod (~2000).
    ///
    /// Same wire protocol as the FT-847, but the internal CAT
    /// transceiver has TX only — the radio does not send status
    /// responses. Uses ``YaesuFT847CAT`` with the
    /// `isUnidirectional: true` initializer flag; all getters throw
    /// `RigError.unsupportedOperation`. Setters continue to work.
    public static let ft847UNI = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-847UNI",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuFT847CAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
                isUnidirectional: true
            )
        }
    )

    /// mcHF QRP — open-source Yaesu-compatible HF QRP kit.
    ///
    /// The mcHF was designed to speak the FT-847 CAT protocol so it
    /// could piggyback on existing CAT-driven digital-mode software.
    /// Uses ``YaesuFT847CAT`` unchanged. Cross-checked against
    /// Hamlib `rigs/yaesu/ft847.c` `RIG_MODEL_MCHFQRP`.
    public static let mchfQRP = RadioDefinition(
        manufacturer: .yaesu,
        model: "mcHF QRP",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuFT847CAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft847
            )
        }
    )

    /// Yaesu FT-920 HF/6m transceiver with DSP
    ///
    /// Uses ``YaesuPortableCAT`` — the FT-920 uses the same 5-byte
    /// binary CAT family as the FT-817 line.
    public static let ft920 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-920",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft920,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft920
            )
        }
    )

    // MARK: - Legacy Models (Pre-2005)

    /// Yaesu FT-1000MP HF 100W flagship transceiver with dual receiver (1995)
    ///
    /// Default baud rate is 4800 — lower than modern Yaesu radios.
    ///
    /// Uses ``YaesuFT1000MPCAT`` — the pre-newcat 5-byte binary CAT
    /// with dual-VFO opcodes (0x0A for VFO A freq, 0x8A for VFO B)
    /// and **little-endian** BCD encoding per Hamlib
    /// `rigs/yaesu/ft1000mp.c`. Fire-and-forget writes; getters throw
    /// `.unsupportedOperation` pending status-block decoder work in a
    /// future release.
    public static let ft1000MP = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-1000MP",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuFT1000MPCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP
            )
        }
    )

    /// Yaesu FT-1000MP MARK-V — 200W upgrade of the FT-1000MP (2000)
    ///
    /// Same CAT protocol as the FT-1000MP per Hamlib
    /// `rigs/yaesu/ft1000mp.c` line 132: "The FT1000MP MARK-V Field
    /// appears to be identical to FT1000MP, whereas the FT1000MP
    /// MARK-V is a FT1000MP with 200W." Only the maxPower differs —
    /// the CAT surface is bit-for-bit identical.
    public static let ft1000MPMkV = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-1000MP MARK-V",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuFT1000MPCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP
            )
        }
    )

    /// Yaesu FT-1000MP MARK-V Field — 100W field-portable variant (2001)
    ///
    /// Same CAT protocol as the FT-1000MP per Hamlib
    /// `rigs/yaesu/ft1000mp.c`.
    public static let ft1000MPMkVField = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-1000MP MARK-V Field",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuFT1000MPCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP
            )
        }
    )

    /// Yaesu FT-857 HF/VHF/UHF 100W compact mobile transceiver (non-D version)
    ///
    /// Uses ``YaesuPortableCAT``.
    public static let ft857 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-857",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft857,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft857
            )
        }
    )

    /// Yaesu FT-897 HF/VHF/UHF 100W base/portable transceiver (non-D version)
    ///
    /// Default baud rate is 4800 — this model predates modern Yaesu high-speed CAT.
    /// Uses ``YaesuPortableCAT``.
    public static let ft897 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-897",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft897,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuPortableCAT(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft897
            )
        }
    )

    /// Yaesu FT-450 HF/6m 100W transceiver (non-D version, predecessor to FT-450D)
    public static let ft450 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-450",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft450,
        serialDefaults: .yaesuHFDesktop,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft450,
                quirks: .ft450
            )
        }
    )
}
