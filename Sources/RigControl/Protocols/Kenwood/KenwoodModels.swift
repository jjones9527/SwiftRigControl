import Foundation

/// Pre-defined Kenwood radio models.
extension RadioDefinition {
    /// Kenwood TS-890S HF/6m transceiver
    public static let kenwoodTS890S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-890S",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS890S,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS890S
            )
        }
    )

    /// Kenwood TS-990S HF/6m transceiver (flagship model)
    public static let kenwoodTS990S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-990S",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS990S,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS990S
            )
        }
    )

    /// Kenwood TS-590SG HF/6m transceiver
    public static let kenwoodTS590SG = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-590SG",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS590SG,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS590SG
            )
        }
    )

    /// Kenwood TM-D710GA VHF/UHF dual-band transceiver
    public static let kenwoodTMD710 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TM-D710",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTMD710,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTMD710
            )
        }
    )

    /// Kenwood TS-480SAT HF/6m all-mode transceiver
    public static let kenwoodTS480SAT = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-480SAT",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS480SAT,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS480SAT
            )
        }
    )

    /// Kenwood TS-2000 HF/VHF/UHF all-mode transceiver
    public static let kenwoodTS2000 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-2000",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS2000,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS2000
            )
        }
    )

    /// Kenwood TS-590S HF/6m transceiver (earlier version of TS-590SG)
    public static let kenwoodTS590S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-590S",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS590S,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS590S
            )
        }
    )

    /// Kenwood TS-870S HF/6m transceiver (classic flagship)
    public static let kenwoodTS870S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-870S",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS870S,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS870S
            )
        }
    )

    /// Kenwood TS-480HX HF/6m 200W transceiver
    public static let kenwoodTS480HX = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-480HX",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTS480HX,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTS480HX
            )
        }
    )

    /// Kenwood TM-V71A VHF/UHF dual-band transceiver with EchoLink
    public static let kenwoodTMV71 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TM-V71",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTMV71,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTMV71
            )
        }
    )

    /// Kenwood TH-D74A tri-band handheld with D-STAR and APRS
    public static let kenwoodTHD74 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D74",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTHD74,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTHD74
            )
        }
    )

    /// Kenwood TH-D72A dual-band handheld with APRS and GPS
    public static let kenwoodTHD72A = RadioDefinition(
        manufacturer: .kenwood,
        model: "TH-D72A",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.kenwoodTHD72A,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.kenwoodTHD72A
            )
        }
    )
}
