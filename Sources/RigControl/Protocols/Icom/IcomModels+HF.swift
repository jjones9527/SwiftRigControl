import Foundation

extension RadioDefinition.Icom {

    // MARK: - Additional HF Transceivers

    /// Icom IC-746 HF/6m/2m receive transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x56)
    /// - Returns: RadioDefinition for IC-746
    public static func ic746(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-746",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic746,
            civAddress: civAddress ?? IcomRadioModel.ic746.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic746,
                    commandSet: IC746CommandSet.ic746,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic746
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic746(civAddress: $0) }
        )
    }

    /// Icom IC-746PRO HF/6m/2m receive transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x66)
    /// - Returns: RadioDefinition for IC-746PRO
    public static func ic746PRO(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-746PRO",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic746PRO,
            civAddress: civAddress ?? IcomRadioModel.ic746pro.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic746pro,
                    commandSet: IC746CommandSet.ic746PRO,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic746PRO
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic746PRO(civAddress: $0) }
        )
    }

    /// Icom IC-756 HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x50)
    /// - Returns: RadioDefinition for IC-756
    public static func ic756(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic756,
            civAddress: civAddress ?? IcomRadioModel.ic756.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756,
                    commandSet: IC756CommandSet.ic756,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic756
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic756(civAddress: $0) }
        )
    }

    /// Icom IC-756PRO HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x5C)
    /// - Returns: RadioDefinition for IC-756PRO
    public static func ic756PRO(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756PRO",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic756PRO,
            civAddress: civAddress ?? IcomRadioModel.ic756pro.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756pro,
                    commandSet: IC756CommandSet.ic756PRO,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic756PRO
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic756PRO(civAddress: $0) }
        )
    }

    /// Icom IC-756PROII HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x64)
    /// - Returns: RadioDefinition for IC-756PROII
    public static func ic756PROII(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756PROII",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic756PROII,
            civAddress: civAddress ?? IcomRadioModel.ic756proII.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756proII,
                    commandSet: IC756CommandSet.ic756PROII,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic756PROII
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic756PROII(civAddress: $0) }
        )
    }

    /// Icom IC-756PROIII HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x6E)
    /// - Returns: RadioDefinition for IC-756PROIII
    public static func ic756PROIII(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756PROIII",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic756PROIII,
            civAddress: civAddress ?? IcomRadioModel.ic756proIII.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756proIII,
                    commandSet: IC756CommandSet.ic756PROIII,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic756PROIII
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic756PROIII(civAddress: $0) }
        )
    }

    /// Icom IC-7200 HF/6m transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x76)
    /// - Returns: RadioDefinition for IC-7200
    public static func ic7200(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7200",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7200,
            civAddress: civAddress ?? IcomRadioModel.ic7200.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7200,
                    commandSet: StandardIcomCommandSet.ic7200,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7200
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic7200(civAddress: $0) }
        )
    }

    /// Icom IC-718 HF budget transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x5E)
    /// - Returns: RadioDefinition for IC-718
    public static func ic718(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-718",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic718,
            civAddress: civAddress ?? IcomRadioModel.ic718.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic718,
                    commandSet: StandardIcomCommandSet.ic718,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic718
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic718(civAddress: $0) }
        )
    }

    /// Icom IC-7410 HF/6m transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x80)
    /// - Returns: RadioDefinition for IC-7410
    public static func ic7410(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7410",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7410,
            civAddress: civAddress ?? IcomRadioModel.ic7410.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7410,
                    commandSet: StandardIcomCommandSet.ic7410,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7410
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic7410(civAddress: $0) }
        )
    }

    /// Icom IC-7700 HF/6m high-power transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x74)
    /// - Returns: RadioDefinition for IC-7700
    public static func ic7700(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7700",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7700,
            civAddress: civAddress ?? IcomRadioModel.ic7700.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7700,
                    commandSet: StandardIcomCommandSet.ic7700,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7700
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic7700(civAddress: $0) }
        )
    }

    /// Icom IC-7800 HF/6m flagship transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x6A)
    /// - Returns: RadioDefinition for IC-7800
    public static func ic7800(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7800",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7800,
            civAddress: civAddress ?? IcomRadioModel.ic7800.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7800,
                    commandSet: StandardIcomCommandSet.ic7800,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7800
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic7800(civAddress: $0) }
        )
    }

    /// Icom IC-7851 HF/6m flagship transceiver with spectrum scope
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x8E)
    /// - Returns: RadioDefinition for IC-7851
    public static func ic7851(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7851",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7851,
            civAddress: civAddress ?? IcomRadioModel.ic7851.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7851,
                    commandSet: StandardIcomCommandSet.ic7851,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7851
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic7851(civAddress: $0) }
        )
    }

    /// Icom IC-7850 HF/6m 200W flagship transceiver (50th Anniversary Limited Edition)
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x8E)
    /// - Returns: RadioDefinition for IC-7850
    public static func ic7850(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7850",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7850,
            civAddress: civAddress ?? IcomRadioModel.ic7850.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7850,
                    commandSet: StandardIcomCommandSet.ic7851,  // Uses same command set as IC-7851
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7850
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic7850(civAddress: $0) }
        )
    }

    /// Icom IC-9100 HF/VHF/UHF transceiver with satellite mode
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x7C)
    /// - Returns: RadioDefinition for IC-9100
    public static func ic9100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-9100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic9100,
            civAddress: civAddress ?? IcomRadioModel.ic9100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic9100,
                    commandSet: StandardIcomCommandSet.ic9100,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic9100
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic9100(civAddress: $0) }
        )
    }

    /// Icom IC-910H VHF/UHF satellite transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x60)
    /// - Returns: RadioDefinition for IC-910H
    public static func ic910H(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-910H",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic910H,
            civAddress: civAddress ?? IcomRadioModel.ic910h.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic910h,
                    commandSet: StandardIcomCommandSet.ic910H,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic910H
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic910H(civAddress: $0) }
        )
    }

    /// Icom IC-820H VHF/UHF dual-band satellite transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x42)
    /// - Returns: RadioDefinition for IC-820H
    public static func ic820H(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-820H",
            defaultBaudRate: 9600,
            capabilities: RadioCapabilitiesDatabase.Icom.ic820H,
            civAddress: civAddress ?? IcomRadioModel.ic820h.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic820h,
                    commandSet: StandardIcomCommandSet.ic910H,  // Uses similar command set
                    capabilities: RadioCapabilitiesDatabase.Icom.ic820H
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.ic820H(civAddress: $0) }
        )
    }

    // MARK: - v1.2.0 Group D — HF SSB commercial-adjacent

    /// Icom IC-F8101 HF SSB transceiver (2010)
    ///
    /// Full-transmit HF 1.6-30 MHz SSB, 100 W. Designed as a
    /// commercial-adjacent land-mobile HF radio but exposes a
    /// standard CI-V CAT interface. Serial link runs at up to
    /// 38400 baud per Hamlib `icf8101.c`.
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x8A)
    /// - Returns: RadioDefinition for IC-F8101
    public static func icF8101(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-F8101",
            defaultBaudRate: 38400,
            capabilities: RadioCapabilitiesDatabase.Icom.icF8101,
            civAddress: civAddress ?? IcomRadioModel.icf8101.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icf8101,
                    commandSet: StandardIcomCommandSet.icF8101,
                    capabilities: RadioCapabilitiesDatabase.Icom.icF8101
                )
            },
            civAddressRebuilder: { RadioDefinition.Icom.icF8101(civAddress: $0) }
        )
    }
}
