import Foundation

extension RadioCapabilitiesDatabase {

    // MARK: - Lab599

    /// Lab599 TX-500 — portable HF transceiver (~2020).
    ///
    /// The TX-500 uses a Kenwood-compatible CAT command set
    /// (modelled on the TS-2000), so it maps to
    /// ``KenwoodProtocol``. Cross-checked against Hamlib
    /// `rigs/kenwood/tx500.c`.
    ///
    /// Features: 10W HF, weatherproof, all-band amateur HF,
    /// optional 6m/2m/70cm receive in some variants.
    public static let lab599TX500 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 10,
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .rttyR, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 300_000, max: 30_000_000),
        detailedFrequencyRanges: [
            // General coverage receive 300 kHz–1.8 MHz
            DetailedFrequencyRange(min: 300_000, max: 1_799_999,
                                    modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000,
                                    modes: [.lsb, .cw, .rtty, .dataLSB],
                                    canTransmit: true, bandName: "160m"),
            // Between bands
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999,
                                    modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000,
                                    modes: [.lsb, .cw, .rtty, .dataLSB],
                                    canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999,
                                    modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000,
                                    modes: [.lsb, .cw, .rtty, .dataLSB],
                                    canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999,
                                    modes: [.usb, .cw, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000,
                                    modes: [.cw, .usb, .rtty, .dataUSB],
                                    canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999,
                                    modes: [.usb, .cw, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000,
                                    modes: [.usb, .cw, .rtty, .dataUSB],
                                    canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999,
                                    modes: [.usb, .cw, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000,
                                    modes: [.usb, .cw, .rtty, .dataUSB],
                                    canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999,
                                    modes: [.usb, .cw, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000,
                                    modes: [.usb, .cw, .rtty, .dataUSB],
                                    canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999,
                                    modes: [.usb, .cw, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000,
                                    modes: [.usb, .cw, .rtty, .dataUSB],
                                    canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999,
                                    modes: [.usb, .cw, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000,
                                    modes: [.usb, .cw, .fm, .am, .rtty, .dataUSB],
                                    canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000,
                                    modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        // Two antenna ports per Hamlib tx500.c:43 (RIG_ANT_1 | RIG_ANT_2).
        antennaCount: 2,
        // Hamlib tx500.c:41 — UP/DOWN/BAND_UP/BAND_DOWN.
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown],
        // Hamlib tx500.c:34 — TONE/TSQL/BC/NB/NR/ANF/COMP/RIT/XIT.
        // (RIT/XIT live on dedicated traits; NB/NR live on
        // SupportsNoiseBlanker/Reduction; here we expose the
        // pure on/off bits.)
        supportedFunctions: [
            .ctcssTone, .ctcssSquelch, .beatCancel, .autoNotch, .compressor,
        ]
    )
}
