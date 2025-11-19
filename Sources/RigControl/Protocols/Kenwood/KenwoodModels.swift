import Foundation

/// Pre-defined Kenwood radio models.
extension RadioDefinition {
    /// Kenwood TS-890S HF/6m transceiver
    public static let kenwoodTS890S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-890S",
        defaultBaudRate: 115200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
            frequencyRange: (min: 30_000, max: 60_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
                    frequencyRange: (min: 30_000, max: 60_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Kenwood TS-990S HF/6m transceiver (flagship model)
    public static let kenwoodTS990S = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-990S",
        defaultBaudRate: 115200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 200,  // 200W
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
            frequencyRange: (min: 30_000, max: 60_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 200,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
                    frequencyRange: (min: 30_000, max: 60_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Kenwood TS-590SG HF/6m transceiver
    public static let kenwoodTS590SG = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-590SG",
        defaultBaudRate: 115200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
            frequencyRange: (min: 30_000, max: 60_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
                    frequencyRange: (min: 30_000, max: 60_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Kenwood TM-D710GA VHF/UHF dual-band transceiver
    public static let kenwoodTMD710 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TM-D710",
        defaultBaudRate: 57600,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: false,
            powerControl: true,
            maxPower: 50,  // 50W VHF, 35W UHF
            supportedModes: [.fm, .fmN],
            frequencyRange: (min: 118_000_000, max: 524_000_000),
            hasDualReceiver: true,
            hasATU: false
        ),
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: false,
                    powerControl: true,
                    maxPower: 50,
                    supportedModes: [.fm, .fmN],
                    frequencyRange: (min: 118_000_000, max: 524_000_000),
                    hasDualReceiver: true,
                    hasATU: false
                )
            )
        }
    )

    /// Kenwood TS-480SAT HF/6m all-mode transceiver
    public static let kenwoodTS480SAT = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-480SAT",
        defaultBaudRate: 57600,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
            frequencyRange: (min: 30_000, max: 60_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
                    frequencyRange: (min: 30_000, max: 60_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Kenwood TS-2000 HF/VHF/UHF all-mode transceiver
    public static let kenwoodTS2000 = RadioDefinition(
        manufacturer: .kenwood,
        model: "TS-2000",
        defaultBaudRate: 57600,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
            frequencyRange: (min: 30_000, max: 1_300_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataLSB],
                    frequencyRange: (min: 30_000, max: 1_300_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )
}
