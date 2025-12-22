import Foundation

/// Pre-defined Icom radio models with support for custom CI-V addresses.
///
/// ## Design Philosophy
/// All Icom radio definitions are **functions** (not static properties) to support
/// custom CI-V addresses. This is critical for users with multiple radios of the same
/// model, where each radio must have a unique address on the CI-V bus.
///
/// ## Usage Examples
///
/// ### Single Radio (Default Address)
/// ```swift
/// let rig = RigController(
///     radio: .icomIC7600(),  // Uses default 0x7A
///     connection: .serial(path: "/dev/ttyUSB0", baudRate: 19200)
/// )
/// ```
///
/// ### Multiple Radios of Same Model (Custom Addresses)
/// ```swift
/// // First IC-7600 with default address
/// let rig1 = RigController(
///     radio: .icomIC7600(),  // Address 0x7A (default)
///     connection: .serial(path: "/dev/ttyUSB0", baudRate: 19200)
/// )
///
/// // Second IC-7600 with custom address (user changed on radio to 0x7B)
/// let rig2 = RigController(
///     radio: .icomIC7600(civAddress: 0x7B),  // Custom address
///     connection: .serial(path: "/dev/ttyUSB1", baudRate: 19200)
/// )
/// ```
extension RadioDefinition {

    // MARK: - HF Transceivers

    /// Icom IC-7600 HF/6m all-mode transceiver with dual receiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x7A)
    /// - Returns: RadioDefinition for IC-7600
    public static func icomIC7600(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7600",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7600,
            civAddress: civAddress ?? IcomRadioModel.ic7600.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7600,
                    commandSet: StandardIcomCommandSet.ic7600,
                    capabilities: RadioCapabilitiesDatabase.icomIC7600
                )
            }
        )
    }

    /// Icom IC-7300 HF/6m all-mode transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x94)
    /// - Returns: RadioDefinition for IC-7300
    public static func icomIC7300(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7300",
            defaultBaudRate: 115200,
            capabilities: RadioCapabilitiesDatabase.icomIC7300,
            civAddress: civAddress ?? IcomRadioModel.ic7300.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7300,
                    commandSet: StandardIcomCommandSet.ic7300,
                    capabilities: RadioCapabilitiesDatabase.icomIC7300
                )
            }
        )
    }

    /// Icom IC-7610 HF/6m SDR transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x98)
    /// - Returns: RadioDefinition for IC-7610
    public static func icomIC7610(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7610",
            defaultBaudRate: 115200,
            capabilities: RadioCapabilitiesDatabase.icomIC7610,
            civAddress: civAddress ?? IcomRadioModel.ic7610.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7610,
                    commandSet: StandardIcomCommandSet.ic7610,
                    capabilities: RadioCapabilitiesDatabase.icomIC7610
                )
            }
        )
    }

    // MARK: - HF/VHF/UHF Multi-band Transceivers

    /// Icom IC-7100 HF/VHF/UHF all-mode transceiver with D-STAR
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x88)
    /// - Returns: RadioDefinition for IC-7100
    public static func icomIC7100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7100,
            civAddress: civAddress ?? IcomRadioModel.ic7100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7100,
                    commandSet: IC7100CommandSet(),
                    capabilities: RadioCapabilitiesDatabase.icomIC7100
                )
            }
        )
    }

    /// Icom IC-9700 VHF/UHF/1.2GHz all-mode transceiver with D-STAR and satellite mode
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0xA2)
    /// - Returns: RadioDefinition for IC-9700
    public static func icomIC9700(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-9700",
            defaultBaudRate: 115200,
            capabilities: RadioCapabilitiesDatabase.icomIC9700,
            civAddress: civAddress ?? IcomRadioModel.ic9700.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic9700,
                    commandSet: IC9700CommandSet(),
                    capabilities: RadioCapabilitiesDatabase.icomIC9700
                )
            }
        )
    }

    /// Icom IC-705 portable HF/VHF/UHF transceiver with D-STAR
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0xA4)
    /// - Returns: RadioDefinition for IC-705
    public static func icomIC705(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-705",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC705,
            civAddress: civAddress ?? IcomRadioModel.ic705.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic705,
                    commandSet: IC7100CommandSet.ic705,
                    capabilities: RadioCapabilitiesDatabase.icomIC705
                )
            }
        )
    }

    /// Icom IC-703 Portable HF/6m QRP transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x68)
    /// - Returns: RadioDefinition for IC-703
    public static func icomIC703(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-703",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC703,
            civAddress: civAddress ?? IcomRadioModel.ic703.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic703,
                    commandSet: StandardIcomCommandSet.ic703,
                    capabilities: RadioCapabilitiesDatabase.icomIC703
                )
            }
        )
    }

    // MARK: - Legacy HF/VHF/UHF Mobile Transceivers

    /// Icom IC-706 HF/6m/2m mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x48)
    /// - Returns: RadioDefinition for IC-706
    public static func icomIC706(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-706",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC706,
            civAddress: civAddress ?? IcomRadioModel.ic706.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic706,
                    commandSet: IC706CommandSet.ic706,
                    capabilities: RadioCapabilitiesDatabase.icomIC706
                )
            }
        )
    }

    /// Icom IC-706MKII HF/6m/2m mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x4E)
    /// - Returns: RadioDefinition for IC-706MKII
    public static func icomIC706MKII(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-706MKII",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC706MKII,
            civAddress: civAddress ?? IcomRadioModel.ic706mkii.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic706mkii,
                    commandSet: IC706CommandSet.ic706MKII,
                    capabilities: RadioCapabilitiesDatabase.icomIC706MKII
                )
            }
        )
    }

    /// Icom IC-706MKIIG HF/VHF/UHF mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x58)
    /// - Returns: RadioDefinition for IC-706MKIIG
    public static func icomIC706MKIIG(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-706MKIIG",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC706MKIIG,
            civAddress: civAddress ?? IcomRadioModel.ic706mkiig.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic706mkiig,
                    commandSet: IC706CommandSet.ic706MKIIG,
                    capabilities: RadioCapabilitiesDatabase.icomIC706MKIIG
                )
            }
        )
    }

    /// Icom IC-7000 HF/VHF/UHF mobile transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x70)
    /// - Returns: RadioDefinition for IC-7000
    public static func icomIC7000(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7000",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7000,
            civAddress: civAddress ?? IcomRadioModel.ic7000.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7000,
                    commandSet: StandardIcomCommandSet.ic7000,
                    capabilities: RadioCapabilitiesDatabase.icomIC7000
                )
            }
        )
    }

    // MARK: - Additional HF Transceivers

    /// Icom IC-746 HF/6m/2m receive transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x56)
    /// - Returns: RadioDefinition for IC-746
    public static func icomIC746(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-746",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC746,
            civAddress: civAddress ?? IcomRadioModel.ic746.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic746,
                    commandSet: IC746CommandSet.ic746,
                    capabilities: RadioCapabilitiesDatabase.icomIC746
                )
            }
        )
    }

    /// Icom IC-746PRO HF/6m/2m receive transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x66)
    /// - Returns: RadioDefinition for IC-746PRO
    public static func icomIC746PRO(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-746PRO",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC746PRO,
            civAddress: civAddress ?? IcomRadioModel.ic746pro.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic746pro,
                    commandSet: IC746CommandSet.ic746PRO,
                    capabilities: RadioCapabilitiesDatabase.icomIC746PRO
                )
            }
        )
    }

    /// Icom IC-756 HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x50)
    /// - Returns: RadioDefinition for IC-756
    public static func icomIC756(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC756,
            civAddress: civAddress ?? IcomRadioModel.ic756.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756,
                    commandSet: IC756CommandSet.ic756,
                    capabilities: RadioCapabilitiesDatabase.icomIC756
                )
            }
        )
    }

    /// Icom IC-756PRO HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x5C)
    /// - Returns: RadioDefinition for IC-756PRO
    public static func icomIC756PRO(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756PRO",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC756PRO,
            civAddress: civAddress ?? IcomRadioModel.ic756pro.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756pro,
                    commandSet: IC756CommandSet.ic756PRO,
                    capabilities: RadioCapabilitiesDatabase.icomIC756PRO
                )
            }
        )
    }

    /// Icom IC-756PROII HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x64)
    /// - Returns: RadioDefinition for IC-756PROII
    public static func icomIC756PROII(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756PROII",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC756PROII,
            civAddress: civAddress ?? IcomRadioModel.ic756proII.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756proII,
                    commandSet: IC756CommandSet.ic756PROII,
                    capabilities: RadioCapabilitiesDatabase.icomIC756PROII
                )
            }
        )
    }

    /// Icom IC-756PROIII HF/6m base station transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x6E)
    /// - Returns: RadioDefinition for IC-756PROIII
    public static func icomIC756PROIII(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-756PROIII",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC756PROIII,
            civAddress: civAddress ?? IcomRadioModel.ic756proIII.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic756proIII,
                    commandSet: IC756CommandSet.ic756PROIII,
                    capabilities: RadioCapabilitiesDatabase.icomIC756PROIII
                )
            }
        )
    }

    /// Icom IC-7200 HF/6m transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x76)
    /// - Returns: RadioDefinition for IC-7200
    public static func icomIC7200(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7200",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7200,
            civAddress: civAddress ?? IcomRadioModel.ic7200.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7200,
                    commandSet: StandardIcomCommandSet.ic7200,
                    capabilities: RadioCapabilitiesDatabase.icomIC7200
                )
            }
        )
    }

    /// Icom IC-718 HF budget transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x5E)
    /// - Returns: RadioDefinition for IC-718
    public static func icomIC718(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-718",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC718,
            civAddress: civAddress ?? IcomRadioModel.ic718.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic718,
                    commandSet: StandardIcomCommandSet.ic718,
                    capabilities: RadioCapabilitiesDatabase.icomIC718
                )
            }
        )
    }

    /// Icom IC-7410 HF/6m transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x80)
    /// - Returns: RadioDefinition for IC-7410
    public static func icomIC7410(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7410",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7410,
            civAddress: civAddress ?? IcomRadioModel.ic7410.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7410,
                    commandSet: StandardIcomCommandSet.ic7410,
                    capabilities: RadioCapabilitiesDatabase.icomIC7410
                )
            }
        )
    }

    /// Icom IC-7700 HF/6m high-power transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x74)
    /// - Returns: RadioDefinition for IC-7700
    public static func icomIC7700(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7700",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7700,
            civAddress: civAddress ?? IcomRadioModel.ic7700.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7700,
                    commandSet: StandardIcomCommandSet.ic7700,
                    capabilities: RadioCapabilitiesDatabase.icomIC7700
                )
            }
        )
    }

    /// Icom IC-7800 HF/6m flagship transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x6A)
    /// - Returns: RadioDefinition for IC-7800
    public static func icomIC7800(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7800",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7800,
            civAddress: civAddress ?? IcomRadioModel.ic7800.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7800,
                    commandSet: StandardIcomCommandSet.ic7800,
                    capabilities: RadioCapabilitiesDatabase.icomIC7800
                )
            }
        )
    }

    /// Icom IC-7851 HF/6m flagship transceiver with spectrum scope
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x8E)
    /// - Returns: RadioDefinition for IC-7851
    public static func icomIC7851(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-7851",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7851,
            civAddress: civAddress ?? IcomRadioModel.ic7851.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic7851,
                    commandSet: StandardIcomCommandSet.ic7851,
                    capabilities: RadioCapabilitiesDatabase.icomIC7851
                )
            }
        )
    }

    /// Icom IC-9100 HF/VHF/UHF transceiver with satellite mode
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x7C)
    /// - Returns: RadioDefinition for IC-9100
    public static func icomIC9100(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-9100",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC9100,
            civAddress: civAddress ?? IcomRadioModel.ic9100.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic9100,
                    commandSet: StandardIcomCommandSet.ic9100,
                    capabilities: RadioCapabilitiesDatabase.icomIC9100
                )
            }
        )
    }

    /// Icom IC-910H VHF/UHF satellite transceiver
    ///
    /// - Parameter civAddress: CI-V bus address (default: 0x60)
    /// - Returns: RadioDefinition for IC-910H
    public static func icomIC910H(civAddress: UInt8? = nil) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .icom,
            model: "IC-910H",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC910H,
            civAddress: civAddress ?? IcomRadioModel.ic910h.defaultCIVAddress,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    civAddress: civAddress,
                    radioModel: .ic910h,
                    commandSet: StandardIcomCommandSet.ic910H,
                    capabilities: RadioCapabilitiesDatabase.icomIC910H
                )
            }
        )
    }

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
