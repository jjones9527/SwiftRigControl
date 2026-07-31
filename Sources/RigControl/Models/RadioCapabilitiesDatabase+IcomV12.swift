import Foundation

// Icom radio capabilities added in v1.2.0 (Group D — receivers and
// specialty): IC-R6, IC-R20, IC-R7100, IC-F8101, ID-1, IC-RX7.
// Extracted from `RadioCapabilitiesDatabase+Icom.swift` in the v1.2.4
// structural refactor.

extension RadioCapabilitiesDatabase.Icom {

    // MARK: - v1.2.0 Group D — receivers + specialty

    /// Icom IC-R6 compact handheld wideband receiver (~2009).
    ///
    /// RX-only 100 kHz – 1.31 GHz, AM/FM/WFM. Per Hamlib
    /// `rigs/icom/icr6.c` the CAT interface does not expose the
    /// memory channel list (`RIG_CHAN_END`), so `getMemoryChannelCount`
    /// returns 0 for this model.
    public static let icR6 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: false,
        maxPower: 0,
        supportedModes: [.am, .fm, .wfm],
        frequencyRange: FrequencyRange(min: 100_000, max: 1_309_995_000),
        detailedFrequencyRanges: [
            // Region 2 (USA) — cellular blocking notches per icr6.c.
            DetailedFrequencyRange(min: 100_000, max: 821_995_000,
                                    modes: [.am, .fm, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 851_000_000, max: 866_995_000,
                                    modes: [.am, .fm, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 896_000_000, max: 1_309_995_000,
                                    modes: [.am, .fm, .wfm],
                                    canTransmit: false),
        ],
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false,
        powerUnits: .percentage,
        antennaCount: 1
    )

    /// Icom IC-R20 dual-VFO handheld wideband receiver (~2004).
    ///
    /// RX-only 150 kHz – 3.305 GHz, AM/CW/SSB/FM/WFM. Two
    /// independent VFOs with simultaneous audio (marketing name:
    /// "Dual receive"). Per Hamlib `rigs/icom/icr20.c` the
    /// memory list is ~1250 channels but is fully CAT-accessible.
    public static let icR20 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: false,
        maxPower: 0,
        supportedModes: [.am, .cw, .cwR, .lsb, .usb, .fm, .fmN, .wfm],
        frequencyRange: FrequencyRange(min: 150_000, max: 3_304_999_000),
        detailedFrequencyRanges: [
            // Region 2 (USA) — cellular blocking notches per icr20.c.
            DetailedFrequencyRange(min: 150_000, max: 821_999_000,
                                    modes: [.am, .cw, .cwR, .lsb, .usb, .fm, .fmN, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 851_000_000, max: 866_999_000,
                                    modes: [.am, .cw, .cwR, .lsb, .usb, .fm, .fmN, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 896_000_000, max: 3_304_999_000,
                                    modes: [.am, .cw, .cwR, .lsb, .usb, .fm, .fmN, .wfm],
                                    canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,
        powerUnits: .percentage,
        antennaCount: 1
    )

    /// Icom IC-R7100 VHF/UHF communications receiver (1993).
    ///
    /// RX-only 25 MHz – 2 GHz, AM/SSB/FM/WFM. Notoriously slow
    /// serial link — Hamlib `rigs/icom/icr7000.c` documents a
    /// 1200 baud maximum, which the factory below honors.
    public static let icR7100 = RigCapabilities(
        hasVFOB: false,
        hasSplit: false,
        powerControl: false,
        maxPower: 0,
        supportedModes: [.am, .lsb, .usb, .fm, .fmN, .wfm],
        frequencyRange: FrequencyRange(min: 25_000_000, max: 2_000_000_000),
        detailedFrequencyRanges: [
            // Two contiguous ranges with a small gap at 1000-1025 MHz
            // per Hamlib icr7000.c.
            DetailedFrequencyRange(min: 25_000_000, max: 1_000_000_000,
                                    modes: [.am, .lsb, .usb, .fm, .fmN, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 1_025_000_000, max: 2_000_000_000,
                                    modes: [.am, .lsb, .usb, .fm, .fmN, .wfm],
                                    canTransmit: false),
        ],
        hasATU: false,
        supportsSignalStrength: false,  // No signal-strength support per icr7000.c LEVEL_NONE
        requiresVFOSelection: false,
        requiresModeFilter: false,
        powerUnits: .percentage,
        antennaCount: 1
    )

    /// Icom IC-F8101 HF SSB transceiver (2010).
    ///
    /// Full-transmit HF 1.6-30 MHz SSB, 100 W. Designed as a
    /// commercial-adjacent land-mobile HF radio but exposes a
    /// standard CI-V CAT interface. Per Hamlib `rigs/icom/icf8101.c`
    /// the serial link tops out at 38400 baud (higher than most
    /// Icom radios of this generation). Modes are LSB, USB, CW,
    /// AM, RTTY (not typical amateur RTTY — vendor mode variant).
    public static let icF8101 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .rtty],
        frequencyRange: FrequencyRange(min: 500_000, max: 29_999_900),
        detailedFrequencyRanges: [
            // RX only below 1.6 MHz; TX allowed 1.6–30 MHz.
            DetailedFrequencyRange(min: 500_000, max: 1_599_999,
                                    modes: [.lsb, .usb, .cw, .am, .rtty],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 1_600_000, max: 29_999_900,
                                    modes: [.lsb, .usb, .cw, .am, .rtty],
                                    canTransmit: true),
        ],
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,
        powerUnits: .percentage,
        antennaCount: 1
    )

    /// Icom ID-1 first-generation 1.2 GHz D-STAR mobile (2004).
    ///
    /// The industry's first D-STAR transceiver. FM voice + 128
    /// kbps DD data mode on the 1240-1300 MHz band, 10 W TX.
    /// Per Hamlib `rigs/icom/id1.c` the CAT interface uses the
    /// unusual 0x01 default CI-V address (the same value the
    /// IC-92AD later reused). Serial link runs at 19200 baud
    /// only (both min and max fixed).
    public static let id1 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 10,
        supportedModes: [.fm],
        frequencyRange: FrequencyRange(min: 1_240_000_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_240_000_000, max: 1_300_000_000,
                                    modes: [.fm],
                                    canTransmit: true),
        ],
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,
        powerUnits: .percentage,
        supportsCTCSS: true,
        supportsDCS: true,
        antennaCount: 1
    )

    /// Icom IC-RX7 compact handheld wideband receiver (2007).
    ///
    /// RX-only 150 kHz – 1.3 GHz, AM/FM/WFM. Very similar spec
    /// to the IC-R6 (which superseded it two years later). Per
    /// Hamlib `rigs/icom/icrx7.c` the CAT interface does not
    /// expose the memory channel list, so `getMemoryChannelCount`
    /// returns 0 for this model.
    public static let icRX7 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: false,
        maxPower: 0,
        supportedModes: [.am, .fm, .wfm],
        frequencyRange: FrequencyRange(min: 150_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            // Region 2 (USA) — cellular blocking notches per icrx7.c.
            DetailedFrequencyRange(min: 150_000, max: 821_995_000,
                                    modes: [.am, .fm, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 851_000_000, max: 866_995_000,
                                    modes: [.am, .fm, .wfm],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 896_000_000, max: 1_300_000_000,
                                    modes: [.am, .fm, .wfm],
                                    canTransmit: false),
        ],
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,
        requiresModeFilter: false,
        powerUnits: .percentage,
        antennaCount: 1
    )
}
