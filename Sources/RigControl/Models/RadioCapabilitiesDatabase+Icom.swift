import Foundation

extension RadioCapabilitiesDatabase {

    // MARK: - Icom Radios

    /// Icom IC-9700 - VHF/UHF/1.2GHz all-mode transceiver
    public static let icomIC9700 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            // HF/VHF General coverage receive only (IC-9700 does NOT transmit on HF or 6m!)
            DetailedFrequencyRange(min: 30_000, max: 143_999_999, modes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm], canTransmit: false),
            // 2m band (144-148 MHz)
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "2m"),
            // General coverage receive VHF/UHF
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .am], canTransmit: false),
            // 70cm band (430-450 MHz)
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "70cm"),
            // General coverage receive UHF
            DetailedFrequencyRange(min: 450_000_001, max: 1_239_999_999, modes: [.fm, .am], canTransmit: false),
            // 23cm band (1240-1300 MHz)
            DetailedFrequencyRange(min: 1_240_000_000, max: 1_300_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "23cm"),
        ],
        hasDualReceiver: true,
        hasATU: false,
        supportsSignalStrength: true,
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000],
        // TX meters — IC-9700 supports the full Icom set
        // (cross-checked against Hamlib IC9700_LEVELS).
        supportsRFPowerMeter: true,
        supportsSWRMeter: true,
        supportsALCMeter: true,
        supportsCompMeter: true,
        supportsVoltageMeter: true,
        supportsCurrentMeter: true,
        // CW keyer — IC-9700 has the full set
        // (KEYSPD/CWPITCH/BKIN/send_morse per Hamlib).
        supportsCWKeyer: true,
        supportsSendCW: true,
        // Scanning — IC-9700 supports MEM, PROG, SLCT per Hamlib
        // IC9700_SCAN_OPS. No VFO/PRIO/DELTA on this radio.
        supportsVFOScan: false,
        supportsMemoryScan: true,
        supportsSelectedMemoryScan: true,
        supportsPriorityScan: false,
        supportsProgrammedScan: true,
        supportsDeltaFScan: false,
        // VFO ops — IC-9700 has no internal ATU, so no TUNE.
        // Matches Hamlib IC9700_VFO_OPS.
        supportedVFOOperations: .icomNoATU,
        supportedFunctions: .icomIC9700Funcs
    )

    /// Icom IC-7610 - HF/6m SDR transceiver
    public static let icomIC7610 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 74_800_000),
        detailedFrequencyRanges: [
            // MW/LW receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 5_330_499, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 60m band
            DetailedFrequencyRange(min: 5_330_500, max: 5_405_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "60m"),
            // General coverage receive
            DetailedFrequencyRange(min: 5_405_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .cw, .cwR, .am, .fm], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 74_800_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        powerUnits: .percentage,
        // VFO ops — IC-7610 uses the standard set (Hamlib uses
        // IC7300_VFO_OPS for both — same family).
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7300Funcs
    )

    /// Icom IC-7300 - HF/6m SDR transceiver
    public static let icomIC7300 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 74_800_000),
        detailedFrequencyRanges: [
            // MW/LW receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 5_330_499, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 60m band
            DetailedFrequencyRange(min: 5_330_500, max: 5_405_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "60m"),
            // General coverage receive
            DetailedFrequencyRange(min: 5_405_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .cw, .cwR, .am, .fm], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 74_800_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        powerUnits: .percentage,
        // VFO ops — IC-7300 standard set per Hamlib IC7300_VFO_OPS.
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7300Funcs
    )

    /// Icom IC-7600 - HF/6m transceiver
    public static let icomIC7600 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // MW/LW receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .cw, .cwR, .am, .fm], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 60_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,  // IC-7600 MUST select Main/Sub before read/write operations
        requiresModeFilter: true,  // IC-7600 requires filter byte in mode commands
        powerUnits: .percentage,
        // TX meters — IC-7600 supports the full Icom set
        // (cross-checked against Hamlib IC7600_LEVELS).
        supportsRFPowerMeter: true,
        supportsSWRMeter: true,
        supportsALCMeter: true,
        supportsCompMeter: true,
        supportsVoltageMeter: true,
        supportsCurrentMeter: true,
        // CW keyer — IC-7600 has the full set
        // (KEYSPD/CWPITCH/BKIN/send_morse per Hamlib).
        supportsCWKeyer: true,
        supportsSendCW: true,
        // Scanning — IC-7600 supports VFO, MEM, PROG, DELTA, PRIO
        // per Hamlib IC7600_SCAN_OPS. No SLCT on this radio.
        supportsVFOScan: true,
        supportsMemoryScan: true,
        supportsSelectedMemoryScan: false,
        supportsPriorityScan: true,
        supportsProgrammedScan: true,
        supportsDeltaFScan: true,
        // Antennas — IC-7600 has two switchable antenna jacks
        // (HF). Per Hamlib IC7600_ANTS = RIG_ANT_1 | RIG_ANT_2.
        antennaCount: 2,
        // VFO ops — matches Hamlib IC7600_VFO_OPS
        // (CPY|XCHG|FROM_VFO|TO_VFO|MCL|TUNE).
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7600Funcs
    )

    /// Icom IC-7100 - HF/VHF/UHF all-mode transceiver
    public static let icomIC7100 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .wfm, .dataUSB, .dataLSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // MW/LW receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .wfm, .am], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            // General coverage receive
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .wfm, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            // General coverage receive
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .wfm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,  // IC-7100 must switch to VFO before operations (.currentOnly model)
        requiresModeFilter: false,  // IC-7100 rejects mode commands with filter byte
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000],
        // TX meters — IC-7100 supports the full Icom set
        // (cross-checked against Hamlib IC7100_LEVEL_ALL).
        supportsRFPowerMeter: true,
        supportsSWRMeter: true,
        supportsALCMeter: true,
        supportsCompMeter: true,
        supportsVoltageMeter: true,
        supportsCurrentMeter: true,
        // CW keyer — IC-7100 has the full set
        // (KEYSPD/CWPITCH/BKIN/send_morse per Hamlib).
        supportsCWKeyer: true,
        supportsSendCW: true,
        // Scanning — IC-7100 supports VFO, MEM, SLCT, PRIO per
        // Hamlib IC7100_SCAN_OPS. No PROG/DELTA on this radio.
        supportsVFOScan: true,
        supportsMemoryScan: true,
        supportsSelectedMemoryScan: true,
        supportsPriorityScan: true,
        supportsProgrammedScan: false,
        supportsDeltaFScan: false,
        // Antennas — IC-7100 has two HF antenna jacks. Per Hamlib
        // IC7100_HF_ANTS = RIG_ANT_1 | RIG_ANT_2. The VHF/UHF
        // jack is fixed and not software-selectable.
        antennaCount: 2,
        // VFO ops — matches Hamlib IC7100_VFO_OPS
        // (FROM_VFO|TO_VFO|CPY|MCL|XCHG|TUNE).
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7100Funcs
    )

    /// Icom IC-705 - HF/VHF/UHF portable transceiver
    public static let icomIC705 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 10,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .wfm, .dataUSB, .dataLSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // MW/LW receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .wfm, .am], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            // General coverage receive
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .wfm, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            // General coverage receive
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .wfm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,  // IC-705 must switch to VFO before operations (.currentOnly model)
        requiresModeFilter: false,  // IC-705 rejects mode commands with filter byte
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000],
        // VFO ops — IC-705 uses IC7300_VFO_OPS per Hamlib
        // (rigs/icom/ic7300.c:1824).
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7300Funcs
    )

    /// Icom IC-703 - Portable HF/6m 10W QRP transceiver
    public static let icomIC703 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 10,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .am, .fm], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 60_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,  // IC-703 doesn't require VFO selection
        requiresModeFilter: true,  // IC-703 requires filter byte in mode commands
        powerUnits: .percentage
    )

    /// Icom IC-905 VHF/UHF/SHF all-mode transceiver.
    public static let icomIC905 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 10,  // 10W 144/430/1200MHz, 2W 2400/5600MHz, 0.5W 10GHz
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN, .dataUSB, .dataFM],
        frequencyRange: FrequencyRange(min: 144_000_000, max: 10_500_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 1_240_000_000, max: 1_300_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "23cm"),
            DetailedFrequencyRange(min: 2_400_000_000, max: 2_450_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "13cm"),
            DetailedFrequencyRange(min: 5_650_000_000, max: 5_850_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "6cm"),
            DetailedFrequencyRange(min: 10_000_000_000, max: 10_500_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .fmN, .dataUSB, .dataFM], canTransmit: true, bandName: "3cm"),
        ],
        hasDualReceiver: true,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage,
        // VFO ops — IC-905 lacks XCHG; TUNE drives an external
        // tuner accessory. Matches Hamlib IC905_VFO_OPS.
        supportedVFOOperations: .icom905
    )

    // MARK: - Icom IC-7760

    /// Icom IC-7760 HF/6m 200W flagship SDR transceiver (2024).
    ///
    /// The IC-7760 is Icom's 2024 successor to the IC-7610 line. It features
    /// dual independent receivers, a large touch display, and CI-V address 0xB0.
    public static let icomIC7760 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN,
                         .dataLSB, .dataUSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 54_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_000, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 9_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .rtty, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_699_999, modes: [.usb, .cw, .fm, .am, .rtty, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_000, max: 49_999_999, modes: [.usb, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .rtty, .dataUSB, .dataFM], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage,
        // VFO ops — IC-7760 is in the IC-7300/IC-7610 family.
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7300Funcs
    )

    // MARK: - Icom IC-7300MK2

    /// Icom IC-7300MK2 HF/6m SDR transceiver — successor to the IC-7300 (2025).
    ///
    /// Shares CI-V address 0x94 with the IC-7300; distinguish by model configuration.
    public static let icomIC7300MK2 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .fmN,
                         .dataLSB, .dataUSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 54_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_000, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 9_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .rtty, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_699_999, modes: [.usb, .cw, .fm, .am, .rtty, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_000, max: 49_999_999, modes: [.usb, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .rtty, .dataUSB, .dataFM], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage,
        // VFO ops — IC-7300MK2 inherits the IC-7300 family set.
        supportedVFOOperations: .icomStandard,
        supportedFunctions: .icomIC7300Funcs
    )
}
