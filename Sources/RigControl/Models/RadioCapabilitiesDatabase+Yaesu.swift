import Foundation

extension RadioCapabilitiesDatabase.Yaesu {
    /// FTX-1 capability surface from Hamlib `rigs/yaesu/ftx1/ftx1.c`.
    /// The 100 W ceiling applies with the SPA-1 amplifier; the field unit
    /// itself is limited to 6 W on battery or 10 W on external DC power.
    public static let ftx1 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .amN,
                         .fm, .fmN, .wfm, .dataUSB, .dataLSB, .dataFM, .dataFMN, .c4fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: {
            let all: Set<Mode> = [.lsb, .usb, .cw, .cwR, .rtty, .rttyR,
                                  .am, .amN, .fm, .fmN, .wfm, .dataUSB,
                                  .dataLSB, .dataFM, .dataFMN, .c4fm]
            let bands: [(UInt64, UInt64, String)] = [
                (1_800_000, 1_999_999, "160m"), (3_500_000, 3_999_999, "80m"),
                (5_167_500, 5_406_500, "60m"), (7_000_000, 7_300_000, "40m"),
                (10_100_000, 10_150_000, "30m"), (14_000_000, 14_350_000, "20m"),
                (18_068_000, 18_168_000, "17m"), (21_000_000, 21_450_000, "15m"),
                (24_890_000, 24_990_000, "12m"), (28_000_000, 29_700_000, "10m"),
                (50_000_000, 54_000_000, "6m"), (144_000_000, 148_000_000, "2m"),
                (430_000_000, 450_000_000, "70cm"),
            ]
            let receiveRanges: [(UInt64, UInt64)] = [
                (30_000, 174_000_000), (400_000_000, 470_000_000),
            ]
            var result: [DetailedFrequencyRange] = []
            for (rxMin, rxMax) in receiveRanges {
                var cursor = rxMin
                for (bandMin, bandMax, name) in bands where bandMax >= rxMin && bandMin <= rxMax {
                    if cursor < bandMin {
                        result.append(DetailedFrequencyRange(min: cursor, max: bandMin - 1, modes: all, canTransmit: false))
                    }
                    result.append(DetailedFrequencyRange(min: bandMin, max: bandMax, modes: all, canTransmit: true, bandName: name))
                    cursor = bandMax + 1
                }
                if cursor <= rxMax {
                    result.append(DetailedFrequencyRange(min: cursor, max: rxMax, modes: all, canTransmit: false))
                }
            }
            return result
        }(),
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        powerUnits: .watts(max: 100),
        supportsRIT: true,
        supportsXIT: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .lock, .manualNotch, .monitor, .vox],
        preampLevels: [10, 20]
    )


    // MARK: - Yaesu Radios

    /// Yaesu FTDX-10 - HF/6m transceiver
    public static let ftdx10 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
            // General coverage receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .stepDown, .stepUp, .toggle, .tune, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10, 20]
    )

    /// Yaesu FT-991A - HF/VHF/UHF all-mode transceiver
    public static let ft991A = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .fmN, .dataUSB, .dataLSB, .dataFM],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // General coverage receive only
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // General coverage receive
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            // General coverage receive
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            // General coverage receive
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000],
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .stepDown, .stepUp, .tune, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10, 20]
    )

    /// Yaesu FT-710 AESS - HF/6m transceiver
    public static let ft710 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
            // Similar to FTDX-10 - HF bands with general coverage
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .stepDown, .stepUp, .toggle, .tune, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10, 20]
    )

    /// Yaesu FT-891 - HF/6m all-mode transceiver
    ///
    /// `hasSplit: false` because the FT-891 supports neither the
    /// `ST` split command nor the `FT` TX-VFO command per Hamlib's
    /// `newcat.c:516,578`. There is no CAT path to establish split
    /// on this radio via the newcat protocol.
    public static let ft891 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .stepDown, .stepUp, .tune, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10]
    )

    /// Yaesu FT-817 - Portable QRP HF/VHF/UHF transceiver
    public static let ft817 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,  // No split on FT-817
        powerControl: true,
        maxPower: 5,  // QRP - 5 watts max
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .fmN, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // Amateur bands
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
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000]
    )

    /// Yaesu FTDX-101D - HF/6m transceiver with dual receiver
    public static let ftdx101D = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: true,  // FTDX-101D has dual receiver
        hasATU: true,
        supportsSignalStrength: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .stepDown, .stepUp, .toggle, .tune, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10, 20]
    )

    /// Yaesu FTDX-101MP - HF/6m 200W flagship transceiver
    public static let ftdx101MP = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,  // 200W version
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .memoryToVFO, .stepDown, .stepUp, .toggle, .tune, .vfoToMemory],
        supportedFunctions: [.autoNotch, .compressor, .ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10, 20]
    )

    /// Yaesu FT-857D - HF/VHF/UHF 100W mobile transceiver
    public static let ft857D = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,  // 100W HF/6m/2m, 50W 70cm
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .fmN, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // HF bands
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            // VHF receive
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            // UHF receive
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            // Upper UHF receive
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,  // No built-in ATU
        supportsSignalStrength: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000]
    )

    /// Yaesu FT-897D - HF/VHF/UHF 100W base/mobile transceiver
    public static let ft897D = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,  // 100W HF/6m/2m, 50W 70cm
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .fmN, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // Same as FT-857D but with built-in ATU
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 143_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999, modes: [.fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,  // FT-897D has built-in ATU
        supportsSignalStrength: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [1, 5, 10, 100, 500, 1000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000]
    )

    /// Yaesu FT-450D - HF/6m 100W budget transceiver
    public static let ft450D = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 56_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .am, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,  // Built-in ATU
        supportsSignalStrength: true,
        supportsCWKeyer: true,
        supportsSendCW: true,
        supportedVFOOperations: [.bandDown, .bandUp, .copyVFO, .exchange, .stepDown, .stepUp, .toggle, .tune],
        supportedFunctions: [.ctcssSquelch, .ctcssTone, .lock, .manualNotch, .monitor, .tuner, .vox],
        preampLevels: [10]
    )

}
