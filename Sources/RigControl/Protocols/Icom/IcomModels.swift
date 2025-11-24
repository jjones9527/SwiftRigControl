import Foundation

/// Pre-defined Icom radio models.
extension RadioDefinition {
    /// Icom IC-9700 VHF/UHF/1.2GHz all-mode transceiver
    public static let icomIC9700 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-9700",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.icomIC9700,
        civAddress: 0xA2,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA2,
                capabilities: RadioCapabilitiesDatabase.icomIC9700
            )
        }
    )

    /// Icom IC-7300 HF/6m all-mode transceiver
    public static let icomIC7300 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7300",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.icomIC7300,
        civAddress: 0x94,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x94,
                capabilities: RadioCapabilitiesDatabase.icomIC7300
            )
        }
    )

    /// Icom IC-7600 HF/6m all-mode transceiver
    public static let icomIC7600 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7600",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7600,
        civAddress: 0x7A,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x7A,
                capabilities: RadioCapabilitiesDatabase.icomIC7600
            )
        }
    )

    /// Icom IC-7100 HF/VHF/UHF all-mode transceiver
    public static let icomIC7100 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7100",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7100,
        civAddress: 0x88,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x88,
                capabilities: RadioCapabilitiesDatabase.icomIC7100
            )
        }
    )

    /// Icom IC-7610 HF/6m SDR transceiver
    public static let icomIC7610 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7610",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.icomIC7610,
        civAddress: 0x98,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x98,
                capabilities: RadioCapabilitiesDatabase.icomIC7610
            )
        }
    )

    /// Icom IC-705 portable HF/VHF/UHF transceiver
    public static let icomIC705 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-705",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC705,
        civAddress: 0xA4,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA4,
                capabilities: RadioCapabilitiesDatabase.icomIC705
            )
        }
    )
}
