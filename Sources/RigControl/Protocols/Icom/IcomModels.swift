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
            defaultBaudRate: 19200,  // Factory default is 19200 baud
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
}
