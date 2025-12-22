import Foundation

/// Pre-defined Yaesu radio models.
extension RadioDefinition {
    /// Yaesu FTDX-10 HF/6m transceiver
    public static let yaesuFTDX10 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-10",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFTDX10,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFTDX10
            )
        }
    )

    /// Yaesu FT-991A HF/VHF/UHF all-mode transceiver
    public static let yaesuFT991A = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991A",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT991A,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT991A
            )
        }
    )

    /// Yaesu FT-710 AESS HF/6m transceiver
    public static let yaesuFT710 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-710",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT710,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT710
            )
        }
    )

    /// Yaesu FT-891 HF/6m all-mode field transceiver
    public static let yaesuFT891 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-891",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT891,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT891
            )
        }
    )

    /// Yaesu FT-817 ultra-compact portable HF/VHF/UHF transceiver
    public static let yaesuFT817 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-817",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT817,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT817
            )
        }
    )

    /// Yaesu FT-DX101D HF/6m transceiver
    public static let yaesuFTDX101D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-101D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFTDX101D,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFTDX101D
            )
        }
    )

    /// Yaesu FTDX-101MP HF/6m 200W flagship transceiver
    public static let yaesuFTDX101MP = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-101MP",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFTDX101MP,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFTDX101MP
            )
        }
    )

    /// Yaesu FT-857D HF/VHF/UHF mobile transceiver
    public static let yaesuFT857D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-857D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT857D,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT857D
            )
        }
    )

    /// Yaesu FT-897D HF/VHF/UHF base/mobile transceiver
    public static let yaesuFT897D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-897D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT897D,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT897D
            )
        }
    )

    /// Yaesu FT-450D HF/6m budget transceiver
    public static let yaesuFT450D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-450D",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT450D,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT450D
            )
        }
    )

    /// Yaesu FT-818 portable QRP HF/VHF/UHF transceiver (successor to FT-817)
    public static let yaesuFT818 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-818",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT818,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT818
            )
        }
    )

    /// Yaesu FT-2000 HF/6m 100W transceiver
    public static let yaesuFT2000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-2000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT2000,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT2000
            )
        }
    )

    /// Yaesu FTDX-3000 HF/6m 100W transceiver
    public static let yaesuFTDX3000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-3000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFTDX3000,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFTDX3000
            )
        }
    )

    /// Yaesu FT-991 HF/VHF/UHF all-mode transceiver (predecessor to FT-991A)
    public static let yaesuFT991 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT991,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT991
            )
        }
    )

    /// Yaesu FT-950 HF/6m 100W transceiver
    public static let yaesuFT950 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-950",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT950,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT950
            )
        }
    )

    /// Yaesu FTDX-5000 HF/6m 200W flagship transceiver
    public static let yaesuFTDX5000 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-5000",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFTDX5000,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFTDX5000
            )
        }
    )

    /// Yaesu FTDX-1200 HF/6m 100W transceiver
    public static let yaesuFTDX1200 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-1200",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFTDX1200,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFTDX1200
            )
        }
    )

    /// Yaesu FT-100 HF/VHF/UHF mobile transceiver
    public static let yaesuFT100 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-100",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.yaesuFT100,
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yaesuFT100
            )
        }
    )
}
