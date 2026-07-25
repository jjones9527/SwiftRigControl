import Foundation

/// Public `RadioDefinition` factories for Ten-Tec radios.
///
/// Every factory here is marked
/// ``RadioDefinition/VerificationStatus/definition`` — no Ten-Tec
/// radio has been exercised against real hardware by the project.
/// The wire protocol implementations (``TenTecOrionProtocol`` and
/// ``TenTecLegacyProtocol``) were audited against Hamlib
/// `rigs/tentec/*.c` on 2026-07-15 as part of the v1.1.2 safety
/// pass; the Ten-Tec Legacy tuning-factor frequency encoding in
/// particular was rewritten to match Hamlib exactly (was sending
/// decimal ASCII the radios silently ignored).
///
/// Until someone runs the corresponding hardware validators, treat
/// these as best-effort: the byte sequences match Hamlib but have
/// not been wire-tested against a live radio since the fix
/// landed. If you validate one, add a `HardwareValidation/`
/// entry and switch the status to
/// ``RadioDefinition/VerificationStatus/hardware`` per project
/// convention.
extension RadioDefinition.TenTec {

    // MARK: - Orion family

    /// Ten-Tec Orion (TT-565) — HF/6m flagship, dual receiver, 100W.
    ///
    /// Uses ``TenTecOrionProtocol`` (hybrid ASCII/binary framing:
    /// `*` set, `?` query, `@` response, all CR-terminated).
    ///
    /// Serial: 57600 baud, 8-N-1, RTS/CTS handshake per Hamlib
    /// `rigs/tentec/orion.h:224-229`.
    public static let orion = RadioDefinition(
        manufacturer: .tentec,
        model: "Orion (TT-565)",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.tenTecOrion,
        serialDefaults: .tentecModern,
        protocolFactory: { transport in
            TenTecOrionProtocol(
                transport: transport,
                radioModel: .orion,
                capabilities: RadioCapabilitiesDatabase.tenTecOrion
            )
        }
    )

    /// Ten-Tec Orion II (TT-599) — updated Orion with improved IF DSP.
    ///
    /// Serial: 57600 baud, 8-N-1, RTS/CTS handshake per Hamlib
    /// `rigs/tentec/orion.h:443-448`.
    public static let orionII = RadioDefinition(
        manufacturer: .tentec,
        model: "Orion II (TT-599)",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.tenTecOrionII,
        serialDefaults: .tentecModern,
        protocolFactory: { transport in
            TenTecOrionProtocol(
                transport: transport,
                radioModel: .orionII,
                capabilities: RadioCapabilitiesDatabase.tenTecOrionII
            )
        }
    )

    /// Ten-Tec Eagle — single-receiver Orion-protocol variant of the TT-599.
    public static let eagle = RadioDefinition(
        manufacturer: .tentec,
        model: "Eagle",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.tenTecEagle,
        serialDefaults: .tentecModern,
        protocolFactory: { transport in
            TenTecOrionProtocol(
                transport: transport,
                radioModel: .eagle,
                capabilities: RadioCapabilitiesDatabase.tenTecEagle
            )
        }
    )

    // MARK: - Legacy family

    /// Ten-Tec Jupiter (TT-538) — compact 100W HF transceiver.
    ///
    /// Uses ``TenTecLegacyProtocol`` (simple ASCII `M`/`N`/`W`
    /// commands, CR-terminated). Frequency is transmitted as
    /// three 16-bit binary tuning factors via the `N` command —
    /// see ``TenTecLegacyProtocol/tuningFactors(freqHz:mode:widthHz:pbtHz:cwBFOHz:)``.
    ///
    /// Serial: 57600 baud, 8-N-1, RTS/CTS handshake per Hamlib
    /// `rigs/tentec/jupiter.c:139-143`.
    public static let jupiter = RadioDefinition(
        manufacturer: .tentec,
        model: "Jupiter (TT-538)",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.tenTecJupiter,
        serialDefaults: .tentecModern,
        protocolFactory: { transport in
            TenTecLegacyProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.tenTecJupiter
            )
        }
    )

    /// Ten-Tec Pegasus (TT-550) — SDR-based 100W HF transceiver
    /// (PC-controlled — the front panel is minimal).
    ///
    /// Serial: 57600 baud, 8-N-1, RTS/CTS handshake per Hamlib
    /// `rigs/tentec/pegasus.c:75-79`.
    public static let pegasus = RadioDefinition(
        manufacturer: .tentec,
        model: "Pegasus (TT-550)",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.tenTecPegasus,
        serialDefaults: .tentecModern,
        protocolFactory: { transport in
            TenTecLegacyProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.tenTecPegasus
            )
        }
    )

    // MARK: - Receivers

    /// Ten-Tec RX-320 — PC-controlled HF general-coverage receiver (1998).
    ///
    /// 100 kHz – 30 MHz continuous RX, AM / CW / SSB, no transmitter.
    /// Uses the same shared `tentec_*` command family as the Jupiter
    /// and Pegasus, so drives via ``TenTecLegacyProtocol``. That
    /// protocol's `setPTT` throws `.unsupportedOperation`, which is
    /// the correct behavior for a receiver.
    ///
    /// Serial: **1200 baud fixed** (both min and max) per Hamlib
    /// `rigs/tentec/rx320.c`.
    public static let rx320 = RadioDefinition(
        manufacturer: .tentec,
        model: "RX-320",
        defaultBaudRate: 1200,
        capabilities: RadioCapabilitiesDatabase.tenTecRX320,
        serialDefaults: .tentecModern,
        protocolFactory: { transport in
            TenTecLegacyProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.tenTecRX320
            )
        }
    )
}
