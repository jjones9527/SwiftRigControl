import Foundation

/// Pre-defined Elecraft radio models.
extension RadioDefinition {
    /// Elecraft K2 HF transceiver
    public static let elecraftK2 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K2",
        defaultBaudRate: 4800,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 15,  // 15 watts (100W with optional PA)
            supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB],
            frequencyRange: (min: 500_000, max: 30_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 15,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB],
                    frequencyRange: (min: 500_000, max: 30_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Elecraft K3 HF/6m transceiver
    public static let elecraftK3 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K3",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
            frequencyRange: (min: 500_000, max: 54_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
                    frequencyRange: (min: 500_000, max: 54_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Elecraft K3S HF/6m transceiver (enhanced K3)
    public static let elecraftK3S = RadioDefinition(
        manufacturer: .elecraft,
        model: "K3S",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
            frequencyRange: (min: 500_000, max: 54_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
                    frequencyRange: (min: 500_000, max: 54_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Elecraft K4 HF/6m SDR transceiver
    public static let elecraftK4 = RadioDefinition(
        manufacturer: .elecraft,
        model: "K4",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
            frequencyRange: (min: 500_000, max: 54_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
                    frequencyRange: (min: 500_000, max: 54_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Elecraft KX2 portable HF transceiver
    public static let elecraftKX2 = RadioDefinition(
        manufacturer: .elecraft,
        model: "KX2",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 12,  // 12 watts internal, 15W with optional batteries
            supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB],
            frequencyRange: (min: 500_000, max: 30_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 12,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB],
                    frequencyRange: (min: 500_000, max: 30_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Elecraft KX3 portable HF/6m transceiver
    public static let elecraftKX3 = RadioDefinition(
        manufacturer: .elecraft,
        model: "KX3",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 15,  // 15 watts internal (can upgrade to 100W with external PA)
            supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
            frequencyRange: (min: 500_000, max: 54_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            ElecraftProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 15,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .am, .dataUSB, .dataLSB],
                    frequencyRange: (min: 500_000, max: 54_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )
}
