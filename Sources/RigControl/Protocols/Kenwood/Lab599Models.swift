import Foundation

extension RadioDefinition.Lab599 {

    /// Lab599 TX-500 — portable HF transceiver (~2020).
    ///
    /// The TX-500 implements a Kenwood-compatible CAT command
    /// set (modelled on the TS-2000), so it reuses
    /// ``KenwoodProtocol`` on the wire. The
    /// ``RadioDefinition/Manufacturer/lab599`` brand tag is
    /// preserved separately so UI can show the operator the
    /// actual radio model rather than mislabelling it as
    /// "Kenwood".
    ///
    /// Baud rate is locked to 9600 per Hamlib
    /// `rigs/kenwood/tx500.c` (`serial_rate_min ==
    /// serial_rate_max == 9600`). Pre-fix code shipped 115200,
    /// which the TX-500 firmware rejects — the radio would appear
    /// unresponsive on every command.
    public static let tx500 = RadioDefinition(
        manufacturer: .lab599,
        model: "TX-500",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.Lab599.tx500,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Lab599.tx500
            )
        }
    )
}
