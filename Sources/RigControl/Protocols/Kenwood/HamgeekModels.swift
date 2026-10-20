import Foundation

extension RadioDefinition.Hamgeek {
    /// Hamgeek uSDX Arduino-based HF transceiver over USB serial or Bluetooth.
    public static let usdx = RadioDefinition(
        manufacturer: .hamgeek,
        model: "uSDX",
        defaultBaudRate: 115_200,
        capabilities: RadioCapabilitiesDatabase.Hamgeek.usdx,
        protocolFactory: { HamgeekUSDXProtocol(transport: $0) },
        preferredDataMode: .usb
    )
}
