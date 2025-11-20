import Foundation

/// Pre-defined Yaesu radio models.
extension RadioDefinition {
    /// Yaesu FTDX-10 HF/6m transceiver
    public static let yaesuFTDX10 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-10",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Yaesu FT-991A HF/VHF/UHF all-mode transceiver
    public static let yaesuFT991A = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-991A",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .fmN, .dataUSB, .dataLSB],
            frequencyRange: FrequencyRange(min: 30_000, max: 450_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .fmN, .dataUSB, .dataLSB],
                    frequencyRange: FrequencyRange(min: 30_000, max: 450_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Yaesu FT-710 AESS HF/6m transceiver
    public static let yaesuFT710 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-710",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Yaesu FT-891 HF/6m all-mode field transceiver
    public static let yaesuFT891 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-891",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
            hasDualReceiver: false,
            hasATU: true
        ),
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
                    hasDualReceiver: false,
                    hasATU: true
                )
            )
        }
    )

    /// Yaesu FT-817 ultra-compact portable HF/VHF/UHF transceiver
    public static let yaesuFT817 = RadioDefinition(
        manufacturer: .yaesu,
        model: "FT-817",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 5,  // 5 watts QRP
            supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .fmN, .dataUSB, .dataLSB],
            frequencyRange: FrequencyRange(min: 100_000, max: 470_000_000),
            hasDualReceiver: false,
            hasATU: false
        ),
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 5,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .fmN, .dataUSB, .dataLSB],
                    frequencyRange: FrequencyRange(min: 100_000, max: 470_000_000),
                    hasDualReceiver: false,
                    hasATU: false
                )
            )
        }
    )

    /// Yaesu FT-DX101D HF/6m transceiver
    public static let yaesuFTDX101D = RadioDefinition(
        manufacturer: .yaesu,
        model: "FTDX-101D",
        defaultBaudRate: 38400,
        capabilities: RigCapabilities(
            hasVFOB: true,
            hasSplit: true,
            powerControl: true,
            maxPower: 100,
            supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
            frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
            hasDualReceiver: true,
            hasATU: true
        ),
        protocolFactory: { transport in
            YaesuCATProtocol(
                transport: transport,
                capabilities: RigCapabilities(
                    hasVFOB: true,
                    hasSplit: true,
                    powerControl: true,
                    maxPower: 100,
                    supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .am, .fm, .dataUSB, .dataLSB],
                    frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
                    hasDualReceiver: true,
                    hasATU: true
                )
            )
        }
    )
}
