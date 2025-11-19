import Foundation

/// Pre-defined Icom radio models.
extension RadioDefinition {
    /// Icom IC-9700 VHF/UHF/1.2GHz all-mode transceiver
    public static let icomIC9700 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-9700",
        defaultBaudRate: 115200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .fm, .fmN, .am, .dataUSB, .dataLSB, .dataFM],
            frequencyRange: (min: 30_000, max: 1_300_000_000),
            hasDualReceiver: true,
            hasATU: false
        ),
        civAddress: 0xA2,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA2,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .fm, .fmN, .am, .dataUSB, .dataLSB, .dataFM],
                    frequencyRange: (min: 30_000, max: 1_300_000_000),
                    hasDualReceiver: true,
                    hasATU: false
                )
            )
        }
    )

    /// Icom IC-7300 HF/6m all-mode transceiver
    public static let icomIC7300 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7300",
        defaultBaudRate: 115200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: (min: 30_000, max: 74_800_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        civAddress: 0x94,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x94,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: (min: 30_000, max: 74_800_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Icom IC-7600 HF/6m all-mode transceiver
    public static let icomIC7600 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7600",
        defaultBaudRate: 19200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: (min: 30_000, max: 60_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        civAddress: 0x7A,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x7A,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: (min: 30_000, max: 60_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Icom IC-7100 HF/VHF/UHF all-mode transceiver
    public static let icomIC7100 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7100",
        defaultBaudRate: 19200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
            frequencyRange: (min: 30_000, max: 470_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        civAddress: 0x88,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x88,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
                    frequencyRange: (min: 30_000, max: 470_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Icom IC-7610 HF/6m SDR transceiver
    public static let icomIC7610 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-7610",
        defaultBaudRate: 115200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: (min: 30_000, max: 74_800_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        civAddress: 0x98,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0x98,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: (min: 30_000, max: 74_800_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )

    /// Icom IC-705 portable HF/VHF/UHF transceiver
    public static let icomIC705 = RadioDefinition(
        manufacturer: .icom,
        model: "IC-705",
        defaultBaudRate: 19200,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 10,  // 10 watts max
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
            frequencyRange: (min: 30_000, max: 470_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        civAddress: 0xA4,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: 0xA4,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 10,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
                    frequencyRange: (min: 30_000, max: 470_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )
}
