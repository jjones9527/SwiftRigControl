import Foundation

extension RadioCapabilitiesDatabase {

    // MARK: - Yaesu FT-991

    /// Yaesu FT-991 - HF/VHF/UHF all-mode transceiver (predecessor to FT-991A)
    public static let yaesuFT991 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,  // 100W HF/50MHz, 50W VHF/UHF
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB, .dataFM], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB, .dataFM], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 117_999_999, modes: [.fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 118_000_000, max: 143_999_999, modes: [.am], canTransmit: false),
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 148_000_001, max: 419_999_999, modes: [.fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 420_000_000, max: 450_000_000, modes: [.usb, .cw, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    // MARK: - Yaesu FT-950

    /// Yaesu FT-950 - HF/6m 100W transceiver
    public static let yaesuFT950 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_099_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_100_000, max: 5_329_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 5_330_500, max: 5_403_500, modes: [.lsb, .usb], canTransmit: true, bandName: "60m"),
            DetailedFrequencyRange(min: 5_403_501, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Yaesu FTDX-5000 HF/6m 200W flagship transceiver with dual receiver
    public static let yaesuFTDX5000 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_099_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_100_000, max: 5_329_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 5_330_500, max: 5_403_500, modes: [.lsb, .usb], canTransmit: true, bandName: "60m"),
            DetailedFrequencyRange(min: 5_403_501, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 60_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Yaesu FTDX-1200 HF/6m 100W transceiver
    public static let yaesuFTDX1200 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_099_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_100_000, max: 5_329_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 5_330_500, max: 5_403_500, modes: [.lsb, .usb], canTransmit: true, bandName: "60m"),
            DetailedFrequencyRange(min: 5_403_501, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Yaesu FT-100 HF/VHF/UHF mobile transceiver
    public static let yaesuFT100 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,  // 100W on HF/6m, 50W on 2m, 20W on 70cm
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 961_000_000),
        detailedFrequencyRanges: [
            // General coverage receive (cellular blocked)
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 2m
            DetailedFrequencyRange(min: 144_000_000, max: 146_000_000, modes: [.usb, .cw, .fm], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 146_000_001, max: 429_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 70cm
            DetailedFrequencyRange(min: 430_000_000, max: 440_000_000, modes: [.usb, .cw, .fm], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 440_000_001, max: 961_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Yaesu FTDX-9000 series HF/6m flagship transceiver (200W/400W)
    public static let yaesuFTDX9000 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 400,  // 400W MP version, 200W D/Contest versions
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_099_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_100_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 60_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Yaesu FT-847 HF/VHF/UHF all-band transceiver
    public static let yaesuFT847 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,  // 100W HF/6m, 50W 2m/70cm
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .fmN, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 512_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 2m
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .fm, .fmN], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 70cm
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .fm, .fmN], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 512_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Yaesu FT-920 HF/6m transceiver with DSP
    public static let yaesuFT920 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,  // 100W SSB/CW, 25W AM
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 56_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_099_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_100_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .am, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: true,
        powerUnits: .percentage
    )


}
