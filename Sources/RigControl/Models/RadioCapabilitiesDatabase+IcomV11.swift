import Foundation

// Icom radio capabilities added in the v1.1.x releases: IC-7760,
// IC-7300MK2, and the D-STAR handheld family (ID-31, ID-51, ID-52,
// IC-92D, IC-R30). Extracted from `RadioCapabilitiesDatabase+Icom.swift`
// in the v1.2.4 structural refactor.

extension RadioCapabilitiesDatabase.Icom {

    // MARK: - Icom IC-7760

    /// Icom IC-7760 HF/6m 200W flagship SDR transceiver (2024).
    ///
    /// The IC-7760 is Icom's 2024 successor to the IC-7610 line. It features
    /// dual independent receivers, a large touch display, and CI-V address 0xB0.
    public static let ic7760 = RigCapabilities(
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
    public static let ic7300MK2 = RigCapabilities(
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

    // MARK: - D-STAR Handhelds (v1.1 parity additions)

    /// Icom ID-31A/E — 2012 single-band UHF D-STAR handheld.
    ///
    /// Cross-checked against Hamlib `rigs/icom/id31.c`. Region-2
    /// (USA) coverage: 440–450 MHz TX, broader UHF receive.
    /// Region-1 (EU) variant transmits 430–440 MHz; we model the
    /// USA defaults here — overrride at the call site if needed.
    public static let id31 = RigCapabilities(
        hasVFOB: false,
        hasSplit: false,
        powerControl: true,
        maxPower: 100,  // Icom uses 0-100% scale
        supportedModes: [.fm, .fmN, .dataFM],
        frequencyRange: FrequencyRange(min: 400_000_000, max: 479_000_000),
        detailedFrequencyRanges: [
            // General receive 400–440 MHz
            DetailedFrequencyRange(min: 400_000_000, max: 439_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // 70cm band (USA TX allocation)
            DetailedFrequencyRange(min: 440_000_000, max: 450_000_000,
                                    modes: [.fm, .fmN, .dataFM], canTransmit: true, bandName: "70cm"),
            // Upper UHF receive
            DetailedFrequencyRange(min: 450_000_001, max: 479_000_000,
                                    modes: [.fm, .fmN], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false,
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        // Hamlib id31.c:45-50 — TONE/TSQL/CSQL/DSQL/VOX.
        supportedFunctions: [.ctcssTone, .ctcssSquelch, .vox]
    )

    /// Icom ID-51A/E / ID-51A Plus2 — 2012/2016 dual-band V/U
    /// D-STAR handheld. Cross-checked against Hamlib
    /// `rigs/icom/id51.c`. Region-2 (USA) high-power variant
    /// (50 W output for the mobile mode) — handheld is 5 W from
    /// internal battery.
    public static let id51 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.fm, .fmN, .dataFM],
        frequencyRange: FrequencyRange(min: 118_000_000, max: 550_000_000),
        detailedFrequencyRanges: [
            // Airband + VHF general receive
            DetailedFrequencyRange(min: 118_000_000, max: 143_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000,
                                    modes: [.fm, .fmN, .dataFM], canTransmit: true, bandName: "2m"),
            // General receive between bands
            DetailedFrequencyRange(min: 148_000_001, max: 374_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // UHF general receive
            DetailedFrequencyRange(min: 375_000_000, max: 429_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000,
                                    modes: [.fm, .fmN, .dataFM], canTransmit: true, bandName: "70cm"),
            // Upper UHF receive
            DetailedFrequencyRange(min: 450_000_001, max: 550_000_000,
                                    modes: [.fm, .fmN], canTransmit: false),
        ],
        hasDualReceiver: true,  // Main/Sub dual-watch
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false,
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        // Hamlib id51.c:47-52 — TONE/TSQL/CSQL/DSQL/VOX.
        supportedFunctions: [.ctcssTone, .ctcssSquelch, .vox]
    )

    /// Icom ID-52A/E / ID-52A Plus2 — 2020/2024 dual-band V/U
    /// D-STAR handheld (successor to ID-51). Cross-checked
    /// against Hamlib `rigs/icom/id52plus.c`. Adds attenuator
    /// support (10 dB / 30 dB) and AMN narrow-AM mode.
    public static let id52 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.fm, .fmN, .am, .dataFM],
        frequencyRange: FrequencyRange(min: 108_000_000, max: 550_000_000),
        detailedFrequencyRanges: [
            // Airband + VHF general receive (108 MHz starts the band)
            DetailedFrequencyRange(min: 108_000_000, max: 143_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000,
                                    modes: [.fm, .fmN, .dataFM], canTransmit: true, bandName: "2m"),
            // General receive between bands
            DetailedFrequencyRange(min: 148_000_001, max: 374_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // UHF general receive
            DetailedFrequencyRange(min: 375_000_000, max: 429_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000,
                                    modes: [.fm, .fmN, .dataFM], canTransmit: true, bandName: "70cm"),
            // Upper UHF receive
            DetailedFrequencyRange(min: 450_000_001, max: 550_000_000,
                                    modes: [.fm, .fmN], canTransmit: false),
        ],
        hasDualReceiver: true,  // Main/Sub dual-watch
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false,
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        // Hamlib id52plus.c:50-55 — TONE/TSQL/CSQL/DSQL/VOX.
        supportedFunctions: [.ctcssTone, .ctcssSquelch, .vox]
    )

    /// Icom IC-92AD / IC-E92D — 2008 dual-band D-STAR handheld
    /// (predecessor to the ID-51 family). Cross-checked against
    /// Hamlib `rigs/icom/ic92d.c`. Notable: 0x01 CI-V address
    /// (unusual for Icom) and full-duplex serial.
    public static let ic92D = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.fm, .fmN, .am, .wfm, .dataFM],
        frequencyRange: FrequencyRange(min: 495_000, max: 999_990_000),
        detailedFrequencyRanges: [
            // Broadband receive (VFO A on the IC-92D)
            DetailedFrequencyRange(min: 495_000, max: 143_999_999,
                                    modes: [.am, .fm, .wfm], canTransmit: false),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000,
                                    modes: [.fm, .fmN, .am, .dataFM],
                                    canTransmit: true, bandName: "2m"),
            // General receive between bands
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999,
                                    modes: [.fm, .fmN, .am, .wfm], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 440_000_000,
                                    modes: [.fm, .fmN, .am, .dataFM],
                                    canTransmit: true, bandName: "70cm"),
            // Upper UHF receive
            DetailedFrequencyRange(min: 440_000_001, max: 999_990_000,
                                    modes: [.fm, .fmN, .am, .wfm], canTransmit: false),
        ],
        hasDualReceiver: true,  // Two VFOs (broadband + 2m/70cm)
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        // Hamlib ic92d.c:43 — FROM_VFO/TO_VFO/MCL.
        supportedVFOOperations: [.vfoToMemory, .memoryToVFO, .memoryClear],
        // Hamlib ic92d.c:35 — MUTE/MON/TONE/TSQL/LOCK/AFC.
        supportedFunctions: [
            .mute, .monitor, .ctcssTone, .ctcssSquelch,
            .lock, .autoFrequencyControl,
        ]
    )

    /// Icom IC-R30 — 2018 wideband digital handheld receiver
    /// (100 kHz–3.3 GHz). Cross-checked against Hamlib
    /// `rigs/icom/icr30.c`. Receiver-only; `setPower` /
    /// `setPTT` will be rejected by the radio.
    public static let icR30 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: false,
        maxPower: 0,
        supportedModes: [.fm, .fmN, .am, .wfm, .lsb, .usb, .cw, .cwR, .dataUSB],
        frequencyRange: FrequencyRange(min: 100_000, max: 3_304_999_900),
        detailedFrequencyRanges: [
            // One huge RX-only range, per Hamlib (Region-2 has
            // notches at 821.995–851 MHz and 866.995–896 MHz to
            // comply with US cellular blocking).
            DetailedFrequencyRange(min: 100_000, max: 821_994_999,
                                    modes: [.fm, .fmN, .am, .wfm, .lsb, .usb, .cw, .cwR, .dataUSB],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 851_000_000, max: 866_994_999,
                                    modes: [.fm, .fmN, .am, .wfm, .lsb, .usb, .cw, .cwR, .dataUSB],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 896_000_000, max: 3_304_999_900,
                                    modes: [.fm, .fmN, .am, .wfm, .lsb, .usb, .cw, .cwR, .dataUSB],
                                    canTransmit: false),
        ],
        hasDualReceiver: true,  // Main/Sub VFOs
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage,
        // 2 antenna ports per Hamlib icr30.c:122 (.ant_count = 2).
        antennaCount: 2,
        // Hamlib icr30.c:43 — FROM_VFO/TO_VFO/MCL.
        supportedVFOOperations: [.vfoToMemory, .memoryToVFO, .memoryClear],
        // Hamlib icr30.c:35-36 — TSQL/AFC/VSC/CSQL/DSQL.
        // (NB/ANL/SCEN are receiver-internal modes we don't expose.)
        supportedFunctions: [
            .ctcssSquelch, .autoFrequencyControl, .voiceSquelch,
        ]
    )
}
