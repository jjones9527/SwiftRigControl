import Foundation

extension RadioDefinition.QRPLabs {
    /// QRP Labs QMX five-band SDR transceiver (definition-only).
    public static let qmx = RadioDefinition(
        manufacturer: .qrpLabs,
        model: "QMX",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.QRPLabs.qmx,
        protocolFactory: { QRPLabsQMXProtocol(transport: $0) },
        preferredDataMode: .usb
    )
}
