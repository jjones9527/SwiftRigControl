import Foundation

extension RadioCapabilitiesDatabase {

    // MARK: - Ten-Tec Orion Family

    /// Ten-Tec Orion (TT-565) — HF/6m flagship, dual receiver, 100W
    public static let tenTecOrion = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: false,  // Power set via front panel only on Orion
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty],
        frequencyRange: FrequencyRange(min: 100_000, max: 54_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 160m
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .usb, .cw, .cwR, .am, .rtty], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 80m
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 40m
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 9_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 30m
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 20m
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 17_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 17m
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 15m
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 12m
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 10m
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .fm, .rtty], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 6m
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false
    )

    /// Ten-Tec Orion II (TT-599) — updated flagship with improved IF DSP
    public static let tenTecOrionII = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: false,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty],
        frequencyRange: FrequencyRange(min: 100_000, max: 54_000_000),
        detailedFrequencyRanges: tenTecOrion.detailedFrequencyRanges,
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false
    )

    /// Ten-Tec Eagle (TT-599 variant) — single-receiver Orion-protocol radio
    public static let tenTecEagle = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: false,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty],
        frequencyRange: FrequencyRange(min: 1_800_000, max: 54_000_000),
        detailedFrequencyRanges: tenTecOrion.detailedFrequencyRanges.filter { $0.canTransmit },
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false
    )

    // MARK: - Ten-Tec Legacy Family

    /// Ten-Tec Jupiter (TT-538) — compact 100W HF transceiver
    public static let tenTecJupiter = RigCapabilities(
        hasVFOB: false,  // Legacy protocol controls VFO A only
        hasSplit: false,
        powerControl: false,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm],
        frequencyRange: FrequencyRange(min: 1_800_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .usb, .cw, .am], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .am], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .fm], canTransmit: true, bandName: "10m"),
        ],
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false
    )

    /// Ten-Tec Pegasus (TT-550) — SDR-based 100W HF transceiver (PC-controlled)
    public static let tenTecPegasus = RigCapabilities(
        hasVFOB: false,
        hasSplit: false,
        powerControl: false,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm],
        frequencyRange: FrequencyRange(min: 1_800_000, max: 30_000_000),
        detailedFrequencyRanges: tenTecJupiter.detailedFrequencyRanges,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false
    )
}
