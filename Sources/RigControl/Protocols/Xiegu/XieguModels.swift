import Foundation

/// Pre-defined Xiegu radio models.
///
/// Xiegu radios use the Icom CI-V protocol, so we leverage the existing
/// IcomCIVProtocol and StandardIcomCommandSet infrastructure.
///
/// ## Xiegu CI-V Protocol
/// - All Xiegu radios use CI-V address **0xA4**
/// - Fixed baud rate: **19200**
/// - Standard Icom command set with minor quirks
/// - VFO model: currentOnly (operates on current VFO)
extension RadioDefinition {
    // MARK: - Xiegu Budget HF Transceivers

    /// Xiegu G90 HF 20W SDR transceiver
    ///
    /// Popular budget HF transceiver extremely popular with new hams
    /// and portable operators (POTA/SOTA).
    ///
    /// **Specifications:**
    /// - Frequency: 0.5-30 MHz RX, 1.8-30 MHz TX (amateur bands)
    /// - Modes: SSB, CW, AM (FM with GSOC controller)
    /// - Power: 20W max
    /// - Built-in automatic antenna tuner
    /// - SDR architecture with spectrum display
    ///
    /// **CI-V Details:**
    /// - Address: 0xA4 (shared with X6100/X6200)
    /// - Baud: 19200
    /// - Protocol: Standard Icom CI-V
    ///
    /// - Returns: RadioDefinition for Xiegu G90
    public static let xieguG90 = RadioDefinition(
        manufacturer: .xiegu,
        model: "G90",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.xieguG90,
        civAddress: 0xA4,  // Xiegu standard CI-V address
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA4,
                radioModel: .xieguG90,  // Will add to IcomRadioModel
                commandSet: StandardIcomCommandSet(
                    civAddress: 0xA4,
                    vfoModel: .currentOnly,
                    requiresModeFilter: true,
                    echoesCommands: false
                ),
                capabilities: RadioCapabilitiesDatabase.xieguG90
            )
        }
    )

    /// Xiegu X6100 HF/6m 10W portable SDR transceiver
    ///
    /// Ultra-portable HF/6m transceiver with built-in battery, touchscreen,
    /// and automatic antenna tuner. Very popular for portable operations.
    ///
    /// **Specifications:**
    /// - Frequency: 0.5-30 MHz + 50-54 MHz RX, amateur bands TX
    /// - Modes: SSB, CW, AM, FM, RTTY
    /// - Power: 10W max (12V), 5W (battery)
    /// - Built-in 3500mAh battery
    /// - 4" touchscreen display
    /// - Built-in automatic antenna tuner
    ///
    /// **CI-V Details:**
    /// - Address: 0xA4
    /// - Baud: 19200
    /// - Protocol: Standard Icom CI-V
    ///
    /// - Returns: RadioDefinition for Xiegu X6100
    public static let xieguX6100 = RadioDefinition(
        manufacturer: .xiegu,
        model: "X6100",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.xieguX6100,
        civAddress: 0xA4,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA4,
                radioModel: .xieguX6100,
                commandSet: StandardIcomCommandSet(
                    civAddress: 0xA4,
                    vfoModel: .currentOnly,
                    requiresModeFilter: true,
                    echoesCommands: false
                ),
                capabilities: RadioCapabilitiesDatabase.xieguX6100
            )
        }
    )

    /// Xiegu X6200 HF/6m 8W portable SDR transceiver
    ///
    /// Latest portable HF/6m transceiver with RF direct sampling,
    /// VHF air band receive, and WFM broadcast receive.
    ///
    /// **Specifications:**
    /// - Frequency: 0.5-30 MHz, 50-54 MHz, 88-136 MHz RX; amateur bands TX
    /// - Modes: SSB, CW, AM, NFM, DIGI, WFM
    /// - Power: 8W max (12V), 5W (battery)
    /// - Built-in 3200mAh battery
    /// - 4" touchscreen display
    /// - Built-in automatic antenna tuner
    /// - VHF air band (108-136 MHz) receive
    /// - FM broadcast (88-108 MHz) receive
    ///
    /// **CI-V Details:**
    /// - Address: 0xA4
    /// - Baud: 19200
    /// - Protocol: Standard Icom CI-V
    ///
    /// - Returns: RadioDefinition for Xiegu X6200
    public static let xieguX6200 = RadioDefinition(
        manufacturer: .xiegu,
        model: "X6200",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.xieguX6200,
        civAddress: 0xA4,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA4,
                radioModel: .xieguX6200,
                commandSet: StandardIcomCommandSet(
                    civAddress: 0xA4,
                    vfoModel: .currentOnly,
                    requiresModeFilter: true,
                    echoesCommands: false
                ),
                capabilities: RadioCapabilitiesDatabase.xieguX6200
            )
        }
    )
}
