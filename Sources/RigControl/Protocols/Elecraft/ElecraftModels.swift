import Foundation

/// Pre-defined Elecraft radio models.
extension RadioDefinition.Elecraft {
    /// Elecraft K2 HF transceiver
    public static let k2 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K2",
        defaultBaudRate: 4800,
        capabilities: RadioCapabilitiesDatabase.Elecraft.k2,
        verificationStatus: .hardware,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Elecraft.k2
            )
        }
    )

    /// Elecraft K3 HF/6m transceiver
    public static let k3 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K3",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Elecraft.k3,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Elecraft.k3
            )
        }
    )

    /// Elecraft K3S HF/6m transceiver (enhanced K3)
    public static let k3S = RadioDefinition(
        manufacturer: .elecraft,
        model: "K3S",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Elecraft.k3S,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Elecraft.k3S
            )
        }
    )

    /// Elecraft K4 HF/6m SDR transceiver
    public static let k4 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K4",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Elecraft.k4,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Elecraft.k4
            )
        }
    )

    /// Elecraft KX2 portable HF transceiver
    public static let kx2 = RadioDefinition(
        manufacturer: .elecraft,
        model: "KX2",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Elecraft.kx2,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Elecraft.kx2
            )
        }
    )

    /// Elecraft KX3 portable HF/6m transceiver
    public static let kx3 = RadioDefinition(
        manufacturer: .elecraft,
        model: "KX3",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Elecraft.kx3,
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Elecraft.kx3
            )
        }
    )
}
