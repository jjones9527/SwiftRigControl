import Foundation

extension RadioCapabilitiesDatabase {

    // MARK: - High-End Icom Flagships

    /// Icom IC-7700 - HF/6m 200W flagship transceiver
    public static let icomIC7700 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // Standard HF bands with general coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,  // IC-7700 can target VFO directly
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-7800 - HF/6m 200W flagship transceiver
    public static let icomIC7800 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // Standard HF bands with general coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,  // IC-7800 has dual receivers
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,  // IC-7800 can target VFO directly
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    // MARK: - Legacy Icom HF Transceivers

    /// Icom IC-7000 - HF/VHF/UHF mobile transceiver
    public static let icomIC7000 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // HF general coverage
            DetailedFrequencyRange(min: 30_000, max: 60_000_000, modes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm], canTransmit: true, bandName: "HF"),
            // 6m
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // 2m
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "2m"),
            // 70cm
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "70cm"),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: false,  // IC-7000 operates on current VFO
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-756PRO - HF/6m transceiver
    public static let icomIC756PRO = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-756PROII - HF/6m transceiver
    public static let icomIC756PROII = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-756PROIII - HF/6m transceiver
    public static let icomIC756PROIII = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,  // IC-756PROIII has dual watch
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-746 - HF/6m/2m receive base station transceiver
    public static let icomIC746 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 174_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            // 2m receive only (108-174 MHz)
            DetailedFrequencyRange(min: 108_000_000, max: 174_000_000, modes: [.fm, .am], canTransmit: false, bandName: "2m RX"),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,  // Legacy mode commands, no filter byte
        powerUnits: .percentage
    )

    /// Icom IC-746PRO - HF/6m/2m receive base station transceiver (enhanced)
    public static let icomIC746PRO = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 174_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            // 2m receive only (108-174 MHz)
            DetailedFrequencyRange(min: 108_000_000, max: 174_000_000, modes: [.fm, .am], canTransmit: false, bandName: "2m RX"),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,  // Legacy mode commands, no filter byte
        powerUnits: .percentage
    )


}
