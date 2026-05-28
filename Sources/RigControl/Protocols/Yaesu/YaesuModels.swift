import Foundation

/// Pre-defined Yaesu radio models.
extension RadioDefinition.Yaesu {
    /// Yaesu FTDX-10 HF/6m transceiver
    public static let ftdx10 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-10",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx10,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx10
            )
        }
    )

    /// Yaesu FT-991A HF/VHF/UHF all-mode transceiver
    public static let ft991A = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991A",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft991A,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft991A
            )
        }
    )

    /// Yaesu FT-710 AESS HF/6m transceiver
    public static let ft710 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-710",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft710,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft710
            )
        }
    )

    /// Yaesu FT-891 HF/6m all-mode field transceiver
    public static let ft891 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-891",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft891,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft891
            )
        }
    )

    /// Yaesu FT-817 ultra-compact portable HF/VHF/UHF transceiver
    public static let ft817 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-817",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft817,
        protocolFactory: { transport in
            YaesuCATProtocol(
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
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101D
            )
        }
    )

    /// Yaesu FTDX-101MP HF/6m 200W flagship transceiver
    public static let ftdx101MP = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-101MP",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101MP,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx101MP
            )
        }
    )

    /// Yaesu FT-857D HF/VHF/UHF mobile transceiver
    public static let ft857D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-857D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft857D,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft857D
            )
        }
    )

    /// Yaesu FT-897D HF/VHF/UHF base/mobile transceiver
    public static let ft897D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-897D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft897D,
        protocolFactory: { transport in
            YaesuCATProtocol(
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
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft450D
            )
        }
    )

    /// Yaesu FT-818 portable QRP HF/VHF/UHF transceiver (successor to FT-817)
    public static let ft818 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-818",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft818,
        protocolFactory: { transport in
            YaesuCATProtocol(
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
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft2000
            )
        }
    )

    /// Yaesu FTDX-3000 HF/6m 100W transceiver
    public static let ftdx3000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-3000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx3000,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx3000
            )
        }
    )

    /// Yaesu FT-991 HF/VHF/UHF all-mode transceiver (predecessor to FT-991A)
    public static let ft991 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft991,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft991
            )
        }
    )

    /// Yaesu FT-950 HF/6m 100W transceiver
    public static let ft950 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-950",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft950,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft950
            )
        }
    )

    /// Yaesu FTDX-5000 HF/6m 200W flagship transceiver
    public static let ftdx5000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-5000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx5000,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx5000
            )
        }
    )

    /// Yaesu FTDX-1200 HF/6m 100W transceiver
    public static let ftdx1200 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-1200",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx1200,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx1200
            )
        }
    )

    /// Yaesu FT-100 HF/VHF/UHF mobile transceiver
    public static let ft100 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-100",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft100,
        protocolFactory: { transport in
            YaesuCATProtocol(
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
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ftdx9000
            )
        }
    )

    /// Yaesu FT-847 HF/VHF/UHF all-band transceiver
    public static let ft847 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-847",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft847
            )
        }
    )

    /// Yaesu FT-920 HF/6m transceiver with DSP
    public static let ft920 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-920",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft920,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft920
            )
        }
    )

    // MARK: - Legacy Models (Pre-2005)

    /// Yaesu FT-1000MP HF 200W flagship transceiver with dual receiver
    ///
    /// Default baud rate is 4800 — lower than modern Yaesu radios.
    public static let ft1000MP = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-1000MP",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft1000MP
            )
        }
    )

    /// Yaesu FT-857 HF/VHF/UHF 100W compact mobile transceiver (non-D version)
    public static let ft857 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-857",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft857,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft857
            )
        }
    )

    /// Yaesu FT-897 HF/VHF/UHF 100W base/portable transceiver (non-D version)
    ///
    /// Default baud rate is 4800 — this model predates modern Yaesu high-speed CAT.
    public static let ft897 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-897",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Yaesu.ft897,
        protocolFactory: { transport in
            YaesuCATProtocol(
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
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Yaesu.ft450
            )
        }
    )
}
