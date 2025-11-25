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
}
