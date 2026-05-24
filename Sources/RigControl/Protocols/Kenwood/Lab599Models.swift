import Foundation

extension RadioDefinition {

    // MARK: - Lab599

    /// Lab599 TX-500 — portable HF transceiver (~2020).
    ///
    /// The TX-500 implements a Kenwood-compatible CAT command
    /// set (modelled on the TS-2000), so it reuses
    /// ``KenwoodProtocol`` on the wire. The
    /// ``RadioDefinition/Manufacturer/lab599`` brand tag is
    /// preserved separately so UI can show the operator the
    /// actual radio model rather than mislabelling it as
    /// "Kenwood".
    public static let lab599TX500 = RadioDefinition(
        manufacturer: .lab599,
        model: "TX-500",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.lab599TX500,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.lab599TX500
            )
        }
    )
}
