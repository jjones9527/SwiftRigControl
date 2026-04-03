import Foundation

extension RadioDefinition {

    // MARK: - VHF/UHF Mobile/D-STAR Transceivers

    /// Icom IC-2730 VHF/UHF dual-band mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x90)
    /// - Returns: RadioDefinition for IC-2730
    public static func icomIC2730(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-2730",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC2730,
            civAddress: civAddress ?? IcomRadioModel.ic2730.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic2730,
                    commandSet: StandardIcomCommandSet.ic2730,
                    capabilities: RadioCapabilitiesDatabase.icomIC2730
                )
            }
        )
    }

    /// Icom ID-4100 VHF/UHF D-STAR mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x9A)
    /// - Returns: RadioDefinition for ID-4100
    public static func icomID4100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-4100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomID4100,
            civAddress: civAddress ?? IcomRadioModel.id4100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id4100,
                    commandSet: StandardIcomCommandSet.id4100,
                    capabilities: RadioCapabilitiesDatabase.icomID4100
                )
            }
        )
    }

    /// Icom ID-5100 VHF/UHF D-STAR mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x8C)
    /// - Returns: RadioDefinition for ID-5100
    public static func icomID5100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-5100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomID5100,
            civAddress: civAddress ?? IcomRadioModel.id5100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id5100,
                    commandSet: StandardIcomCommandSet.id5100,
                    capabilities: RadioCapabilitiesDatabase.icomID5100
                )
            }
        )
    }

    // MARK: - Receivers

    /// Icom IC-R75 HF communications receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x5A)
    /// - Returns: RadioDefinition for IC-R75
    public static func icomICR75(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R75",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomICR75,
            civAddress: civAddress ?? IcomRadioModel.icr75.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr75,
                    commandSet: StandardIcomCommandSet.icR75,
                    capabilities: RadioCapabilitiesDatabase.icomICR75
                )
            }
        )
    }

    /// Icom IC-R8600 wideband communications receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x96)
    /// - Returns: RadioDefinition for IC-R8600
    public static func icomICR8600(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R8600",
            defaultBaudRate: 115200,
            capabilities: RadioCapabilitiesDatabase.icomICR8600,
            civAddress: civAddress ?? IcomRadioModel.icr8600.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr8600,
                    commandSet: StandardIcomCommandSet.icR8600,
                    capabilities: RadioCapabilitiesDatabase.icomICR8600
                )
            }
        )
    }

    /// Icom IC-R9500 professional wideband communications receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x72)
    /// - Returns: RadioDefinition for IC-R9500
    public static func icomICR9500(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R9500",
            defaultBaudRate: 1200,
            capabilities: RadioCapabilitiesDatabase.icomICR9500,
            civAddress: civAddress ?? IcomRadioModel.icr9500.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr9500,
                    commandSet: StandardIcomCommandSet.icR9500,
                    capabilities: RadioCapabilitiesDatabase.icomICR9500
                )
            }
        )
    }

    /// Icom IC-905 VHF/UHF/SHF all-mode transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0xAC)
    /// - Returns: RadioDefinition for IC-905
    public static func icomIC905(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-905",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC905,
            civAddress: civAddress ?? IcomRadioModel.ic905.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic905,
                    commandSet: StandardIcomCommandSet.ic9100,
                    capabilities: RadioCapabilitiesDatabase.icomIC905
                )
            }
        )
    }

    /// Icom IC-7400 HF/6m/2m transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x66)
    /// - Returns: RadioDefinition for IC-7400
    public static func icomIC7400(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7400",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7400,
            civAddress: civAddress ?? IcomRadioModel.ic7400.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7400,
                    commandSet: StandardIcomCommandSet.ic7600,
                    capabilities: RadioCapabilitiesDatabase.icomIC7400
                )
            }
        )
    }

    /// Icom IC-735 HF all-mode transceiver (classic)
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x04)
    /// - Returns: RadioDefinition for IC-735
    public static func icomIC735(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-735",
            defaultBaudRate: 1200,
            capabilities: RadioCapabilitiesDatabase.icomIC735,
            civAddress: civAddress ?? IcomRadioModel.ic735.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic735,
                    commandSet: StandardIcomCommandSet.ic718,
                    capabilities: RadioCapabilitiesDatabase.icomIC735
                )
            }
        )
    }

    /// Icom IC-751 HF all-mode transceiver (classic)
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x1C)
    /// - Returns: RadioDefinition for IC-751
    public static func icomIC751(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-751",
            defaultBaudRate: 1200,
            capabilities: RadioCapabilitiesDatabase.icomIC751,
            civAddress: civAddress ?? IcomRadioModel.ic751.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic751,
                    commandSet: StandardIcomCommandSet.ic718,
                    capabilities: RadioCapabilitiesDatabase.icomIC751
                )
            }
        )
    }

    /// Icom IC-970 VHF/UHF all-mode transceiver with satellite mode
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x2E)
    /// - Returns: RadioDefinition for IC-970
    public static func icomIC970(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-970",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC970,
            civAddress: civAddress ?? IcomRadioModel.ic970.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic970,
                    commandSet: StandardIcomCommandSet.ic9100,
                    capabilities: RadioCapabilitiesDatabase.icomIC970
                )
            }
        )
    }

    // MARK: - Backward Compatibility

    /// Legacy IC-9700 definition (static property for backward compatibility)
    @available(*, deprecated, message: "Use icomIC9700(civAddress:) function instead")
    public static let icomIC9700 = icomIC9700()

    /// Legacy IC-7300 definition (static property for backward compatibility)
    @available(*, deprecated, message: "Use icomIC7300(civAddress:) function instead")
    public static let icomIC7300 = icomIC7300()

    /// Legacy IC-7600 definition (static property for backward compatibility)
    @available(*, deprecated, message: "Use icomIC7600(civAddress:) function instead")
    public static let icomIC7600 = icomIC7600()

    /// Legacy IC-7100 definition (static property for backward compatibility)
    @available(*, deprecated, message: "Use icomIC7100(civAddress:) function instead")
    public static let icomIC7100 = icomIC7100()

    /// Legacy IC-7610 definition (static property for backward compatibility)
    @available(*, deprecated, message: "Use icomIC7610(civAddress:) function instead")
    public static let icomIC7610 = icomIC7610()

    /// Legacy IC-705 definition (static property for backward compatibility)
    @available(*, deprecated, message: "Use icomIC705(civAddress:) function instead")
    public static let icomIC705 = icomIC705()
}
