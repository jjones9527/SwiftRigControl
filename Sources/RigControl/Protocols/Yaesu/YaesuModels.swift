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
                quirks: .newcatWithSTDX
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
                quirks: .newcatWithSTDX
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
                quirks: .newcatWithSTDX
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
                quirks: .newcatNoST
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
                quirks: .newcatNoST
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
                quirks: .newcatNoST
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
                quirks: .newcatNoST
            )
        }
    )

    /// Yaesu FT-847 HF/VHF/UHF all-band transceiver
    ///
    /// > Warning: This definition currently uses ``YaesuCATProtocol``,
    /// > which is the modern **newcat** driver. The FT-847 actually
    /// > uses a distinct pre-newcat 5-byte binary CAT with satellite
    /// > VFO opcodes (per Hamlib `rigs/yaesu/ft847.c`). CAT operations
    /// > against a real FT-847 will not work correctly until a
    /// > dedicated `YaesuFT847Protocol` lands in a follow-up release.
    /// > The FT-817 family (FT-817/818/857/857D/897/897D/100/920) was
    /// > migrated to ``YaesuPortableCAT`` in this release; FT-847
    /// > deserves its own port because it adds satellite-mode VFO
    /// > tagging (opcodes 0x03/0x13/0x23) that the FT-817 family
    /// > doesn't have.
    public static let ft847 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-847",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuCATProtocol(
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

    /// Yaesu FT-1000MP HF 200W flagship transceiver with dual receiver
    ///
    /// Default baud rate is 4800 — lower than modern Yaesu radios.
    ///
    /// > Warning: This definition currently uses ``YaesuCATProtocol``,
    /// > which is the modern **newcat** driver. The FT-1000MP actually
    /// > uses a distinct pre-newcat 5-byte binary CAT with dual-VFO
    /// > opcodes (0x0A/0x8A) and **little-endian** BCD encoding (per
    /// > Hamlib `rigs/yaesu/ft1000mp.c`) — the opposite endian to the
    /// > FT-817 family's ``YaesuPortableCAT``. CAT operations against
    /// > a real FT-1000MP will not work correctly until a dedicated
    /// > `YaesuFT1000MPProtocol` lands in a follow-up release.
    public static let ft1000MP = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-1000MP",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP,
        serialDefaults: .yaesuHFPortable,
        protocolFactory: { transport in
            YaesuCATProtocol(
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
