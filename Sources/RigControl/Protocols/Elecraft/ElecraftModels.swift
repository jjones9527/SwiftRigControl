import Foundation

/// Pre-defined Elecraft radio models.
extension RadioDefinition {
    /// Elecraft K2 HF transceiver
    public static let elecraftK2 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K2",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.elecraftK2,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.elecraftK2
            )
        }
    )

    /// Elecraft K3 HF/6m transceiver
    public static let elecraftK3 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K3",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.elecraftK3,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.elecraftK3
            )
        }
    )

    /// Elecraft K3S HF/6m transceiver (enhanced K3)
    public static let elecraftK3S = RadioDefinition(
        manufacturer: .elecraft,
        model: "K3S",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.elecraftK3S,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.elecraftK3S
            )
        }
    )

    /// Elecraft K4 HF/6m SDR transceiver
    public static let elecraftK4 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K4",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.elecraftK4,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.elecraftK4
            )
        }
    )

    /// Elecraft KX2 portable HF transceiver
    public static let elecraftKX2 = RadioDefinition(
        manufacturer: .elecraft,
        model: "KX2",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.elecraftKX2,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.elecraftKX2
            )
        }
    )

    /// Elecraft KX3 portable HF/6m transceiver
    public static let elecraftKX3 = RadioDefinition(
        manufacturer: .elecraft,
        model: "KX3",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.elecraftKX3,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.elecraftKX3
            )
        }
    )
}
