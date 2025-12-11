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
}
