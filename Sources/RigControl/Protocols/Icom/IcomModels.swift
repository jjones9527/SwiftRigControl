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
