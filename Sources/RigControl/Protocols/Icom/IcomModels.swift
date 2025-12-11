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
                commandSet: IC9700CommandSet(),
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
                commandSet: StandardIcomCommandSet.ic7300,
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
                commandSet: StandardIcomCommandSet.ic7600,
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
                commandSet: IC7100CommandSet(),
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
                commandSet: StandardIcomCommandSet.ic7610,
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
                commandSet: IC7100CommandSet.ic705,
                capabilities: RadioCapabilitiesDatabase.icomIC705
            )
        }
    )

    /// Icom IC-9100 HF/VHF/UHF all-mode transceiver
    public static let icomIC9100 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-9100",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.icomIC9100,
        civAddress: 0x7C,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic9100,
                capabilities: RadioCapabilitiesDatabase.icomIC9100
            )
        }
    )

    /// Icom IC-7200 HF/6m all-mode transceiver
    public static let icomIC7200 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7200",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7200,
        civAddress: 0x76,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic7200,
                capabilities: RadioCapabilitiesDatabase.icomIC7200
            )
        }
    )

    /// Icom IC-7410 HF/6m all-mode transceiver
    public static let icomIC7410 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7410",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7410,
        civAddress: 0x80,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic7410,
                capabilities: RadioCapabilitiesDatabase.icomIC7410
            )
        }
    )

    // MARK: - High-End Icom Flagships

    /// Icom IC-7700 HF/6m 200W flagship transceiver
    public static let icomIC7700 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7700",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7700,
        civAddress: 0x74,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic7700,
                capabilities: RadioCapabilitiesDatabase.icomIC7700
            )
        }
    )

    /// Icom IC-7800 HF/6m 200W flagship transceiver
    public static let icomIC7800 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7800",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7800,
        civAddress: 0x6A,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic7800,
                capabilities: RadioCapabilitiesDatabase.icomIC7800
            )
        }
    )

    // MARK: - Legacy Icom HF Transceivers

    /// Icom IC-7000 HF/VHF/UHF mobile transceiver
    public static let icomIC7000 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7000",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7000,
        civAddress: 0x70,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic7000,
                capabilities: RadioCapabilitiesDatabase.icomIC7000
            )
        }
    )

    /// Icom IC-756PRO HF/6m transceiver
    public static let icomIC756PRO = RadioDefinition(
        manufacturer: .icom,
        model: "IC-756PRO",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC756PRO,
        civAddress: 0x5C,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic756PRO,
                capabilities: RadioCapabilitiesDatabase.icomIC756PRO
            )
        }
    )

    /// Icom IC-756PROII HF/6m transceiver
    public static let icomIC756PROII = RadioDefinition(
        manufacturer: .icom,
        model: "IC-756PROII",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC756PROII,
        civAddress: 0x64,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic756PROII,
                capabilities: RadioCapabilitiesDatabase.icomIC756PROII
            )
        }
    )

    /// Icom IC-756PROIII HF/6m transceiver
    public static let icomIC756PROIII = RadioDefinition(
        manufacturer: .icom,
        model: "IC-756PROIII",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC756PROIII,
        civAddress: 0x6E,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic756PROIII,
                capabilities: RadioCapabilitiesDatabase.icomIC756PROIII
            )
        }
    )

    /// Icom IC-746PRO HF/VHF transceiver
    public static let icomIC746PRO = RadioDefinition(
        manufacturer: .icom,
        model: "IC-746PRO",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC746PRO,
        civAddress: 0x66,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.ic746PRO,
                capabilities: RadioCapabilitiesDatabase.icomIC746PRO
            )
        }
    )

    // MARK: - Icom D-STAR Mobiles

    /// Icom ID-5100 VHF/UHF D-STAR mobile transceiver
    public static let icomID5100 = RadioDefinition(
        manufacturer: .icom,
        model: "ID-5100",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomID5100,
        civAddress: 0x86,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.id5100,
                capabilities: RadioCapabilitiesDatabase.icomID5100
            )
        }
    )

    /// Icom ID-4100 VHF/UHF D-STAR mobile transceiver
    public static let icomID4100 = RadioDefinition(
        manufacturer: .icom,
        model: "ID-4100",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomID4100,
        civAddress: 0x76,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.id4100,
                capabilities: RadioCapabilitiesDatabase.icomID4100
            )
        }
    )

    // MARK: - Icom Receivers

    /// Icom IC-R8600 wideband communications receiver
    public static let icomICR8600 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-R8600",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.icomICR8600,
        civAddress: 0x96,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.icR8600,
                capabilities: RadioCapabilitiesDatabase.icomICR8600
            )
        }
    )

    /// Icom IC-R75 HF communications receiver
    public static let icomICR75 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-R75",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomICR75,
        civAddress: 0x5A,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.icR75,
                capabilities: RadioCapabilitiesDatabase.icomICR75
            )
        }
    )

    /// Icom IC-R9500 professional communications receiver
    public static let icomICR9500 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-R9500",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomICR9500,
        civAddress: 0x7A,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                commandSet: StandardIcomCommandSet.icR9500,
                capabilities: RadioCapabilitiesDatabase.icomICR9500
            )
        }
    )
}
