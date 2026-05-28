import Foundation

extension RadioDefinition.Icom {

    // MARK: - VHF/UHF Mobile/D-STAR Transceivers

    /// Icom IC-2730 VHF/UHF dual-band mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x90)
    /// - Returns: RadioDefinition for IC-2730
    public static func ic2730(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-2730",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic2730,
            civAddress: civAddress ?? IcomRadioModel.ic2730.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic2730,
                    commandSet: StandardIcomCommandSet.ic2730,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic2730
                )
            }
        )
    }

    /// Icom ID-4100 VHF/UHF D-STAR mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x9A)
    /// - Returns: RadioDefinition for ID-4100
    public static func id4100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-4100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.id4100,
            civAddress: civAddress ?? IcomRadioModel.id4100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id4100,
                    commandSet: StandardIcomCommandSet.id4100,
                    capabilities: RadioCapabilitiesDatabase.Icom.id4100
                )
            }
        )
    }

    /// Icom ID-5100 VHF/UHF D-STAR mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x8C)
    /// - Returns: RadioDefinition for ID-5100
    public static func id5100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-5100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.id5100,
            civAddress: civAddress ?? IcomRadioModel.id5100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id5100,
                    commandSet: StandardIcomCommandSet.id5100,
                    capabilities: RadioCapabilitiesDatabase.Icom.id5100
                )
            }
        )
    }

    // MARK: - Receivers

    /// Icom IC-R75 HF communications receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x5A)
    /// - Returns: RadioDefinition for IC-R75
    public static func icR75(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R75",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.icR75,
            civAddress: civAddress ?? IcomRadioModel.icr75.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr75,
                    commandSet: StandardIcomCommandSet.icR75,
                    capabilities: RadioCapabilitiesDatabase.Icom.icR75
                )
            }
        )
    }

    /// Icom IC-R8600 wideband communications receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x96)
    /// - Returns: RadioDefinition for IC-R8600
    public static func icR8600(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R8600",
            defaultBaudRate: 115200,
            capabilities: RadioCapabilitiesDatabase.Icom.icR8600,
            civAddress: civAddress ?? IcomRadioModel.icr8600.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr8600,
                    commandSet: StandardIcomCommandSet.icR8600,
                    capabilities: RadioCapabilitiesDatabase.Icom.icR8600
                )
            }
        )
    }

    /// Icom IC-R9500 professional wideband communications receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x72)
    /// - Returns: RadioDefinition for IC-R9500
    public static func icR9500(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R9500",
            defaultBaudRate: 1200,
            capabilities: RadioCapabilitiesDatabase.Icom.icR9500,
            civAddress: civAddress ?? IcomRadioModel.icr9500.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr9500,
                    commandSet: StandardIcomCommandSet.icR9500,
                    capabilities: RadioCapabilitiesDatabase.Icom.icR9500
                )
            }
        )
    }

    /// Icom IC-905 VHF/UHF/SHF all-mode transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0xAC)
    /// - Returns: RadioDefinition for IC-905
    public static func ic905(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-905",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic905,
            civAddress: civAddress ?? IcomRadioModel.ic905.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic905,
                    commandSet: StandardIcomCommandSet.ic9100,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic905
                )
            }
        )
    }

    /// Icom IC-7400 HF/6m/2m transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x66)
    /// - Returns: RadioDefinition for IC-7400
    public static func ic7400(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7400",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7400,
            civAddress: civAddress ?? IcomRadioModel.ic7400.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7400,
                    commandSet: StandardIcomCommandSet.ic7600,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic7400
                )
            }
        )
    }

    /// Icom IC-735 HF all-mode transceiver (classic)
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x04)
    /// - Returns: RadioDefinition for IC-735
    public static func ic735(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-735",
            defaultBaudRate: 1200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic735,
            civAddress: civAddress ?? IcomRadioModel.ic735.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic735,
                    commandSet: StandardIcomCommandSet.ic718,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic735
                )
            }
        )
    }

    /// Icom IC-751 HF all-mode transceiver (classic)
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x1C)
    /// - Returns: RadioDefinition for IC-751
    public static func ic751(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-751",
            defaultBaudRate: 1200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic751,
            civAddress: civAddress ?? IcomRadioModel.ic751.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic751,
                    commandSet: StandardIcomCommandSet.ic718,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic751
                )
            }
        )
    }

    /// Icom IC-970 VHF/UHF all-mode transceiver with satellite mode
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x2E)
    /// - Returns: RadioDefinition for IC-970
    public static func ic970(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-970",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.Icom.ic970,
            civAddress: civAddress ?? IcomRadioModel.ic970.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic970,
                    commandSet: StandardIcomCommandSet.ic9100,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic970
                )
            }
        )
    }

    // MARK: - D-STAR Handhelds (v1.1 parity additions)

    /// Icom ID-31A/E single-band UHF D-STAR handheld (2012).
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0xA0)
    /// - Returns: RadioDefinition for ID-31
    public static func id31(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-31",
            defaultBaudRate: 9600,
            capabilities: RadioCapabilitiesDatabase.Icom.id31,
            civAddress: civAddress ?? IcomRadioModel.id31.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id31,
                    commandSet: StandardIcomCommandSet.id31,
                    capabilities: RadioCapabilitiesDatabase.Icom.id31
                )
            }
        )
    }

    /// Icom ID-51A/E / ID-51A Plus2 dual-band V/U D-STAR
    /// handheld (2012 / 2016).
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x86)
    /// - Returns: RadioDefinition for ID-51
    public static func id51(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-51",
            defaultBaudRate: 9600,
            capabilities: RadioCapabilitiesDatabase.Icom.id51,
            civAddress: civAddress ?? IcomRadioModel.id51.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id51,
                    commandSet: StandardIcomCommandSet.id51,
                    capabilities: RadioCapabilitiesDatabase.Icom.id51
                )
            }
        )
    }

    /// Icom ID-52A/E / ID-52A Plus2 dual-band V/U D-STAR
    /// handheld (2020 / 2024).
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0xB4)
    /// - Returns: RadioDefinition for ID-52
    public static func id52(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "ID-52",
            defaultBaudRate: 9600,
            capabilities: RadioCapabilitiesDatabase.Icom.id52,
            civAddress: civAddress ?? IcomRadioModel.id52.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .id52,
                    commandSet: StandardIcomCommandSet.id52,
                    capabilities: RadioCapabilitiesDatabase.Icom.id52
                )
            }
        )
    }

    /// Icom IC-92AD / IC-E92D dual-band D-STAR handheld (2008).
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x01 —
    ///   unusual for Icom; per Hamlib `ic92d.c`).
    /// - Returns: RadioDefinition for IC-92D
    public static func ic92D(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-92D",
            defaultBaudRate: 9600,
            capabilities: RadioCapabilitiesDatabase.Icom.ic92D,
            civAddress: civAddress ?? IcomRadioModel.ic92d.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic92d,
                    commandSet: StandardIcomCommandSet.ic92d,
                    capabilities: RadioCapabilitiesDatabase.Icom.ic92D
                )
            }
        )
    }

    /// Icom IC-R30 wideband digital handheld receiver (2018).
    /// 100 kHz–3.3 GHz coverage; receiver only — `setPTT` and
    /// `setPower` will be rejected by the radio.
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x9C)
    /// - Returns: RadioDefinition for IC-R30
    public static func icR30(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-R30",
            defaultBaudRate: 9600,
            capabilities: RadioCapabilitiesDatabase.Icom.icR30,
            civAddress: civAddress ?? IcomRadioModel.icr30.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .icr30,
                    commandSet: StandardIcomCommandSet.icR30,
                    capabilities: RadioCapabilitiesDatabase.Icom.icR30
                )
            }
        )
    }
}
