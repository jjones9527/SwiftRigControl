import Foundation

// Kenwood radio capabilities for legacy HF and TM/TH mobile /
// handheld families. Extracted from
// `RadioCapabilitiesDatabase+Kenwood.swift` in the v1.2.4 structural
// refactor. Contains:
//   * Legacy HF: TS-850S, TS-570D, TS-570S, TH-D72A
//   * v1.2.0 legacy HF: TS-450S, TS-690S, TS-940S, TS-950S, TS-950SDX
//   * v1.2.0 TM/TH-F CR-terminated CAT: TM-D710, TM-V71, TH-F6A, TH-F7E

extension RadioCapabilitiesDatabase.Kenwood {

    // MARK: - Legacy Kenwood HF Radios

    /// Kenwood TS-850S - HF 100W transceiver with internal ATU
    ///
    /// Classic late-90s flagship. HF-only (no 6m), 1200 baud default CAT.
    public static let ts850S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 100_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true
    )

    /// Kenwood TS-570D - HF/6m 100W transceiver with internal ATU and DSP
    ///
    /// Late-90s mid-range transceiver with optional 6m coverage. 4800 baud default CAT.
    /// The TS-570D includes 6m; the TS-570S does not.
    public static let ts570D = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 56_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            DetailedFrequencyRange(min: 54_000_001, max: 56_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true
    )

    /// Kenwood TS-570S - HF-only 100W transceiver with DSP (no 6m, no ATU)
    ///
    /// Budget sibling of the TS-570D. HF bands only, no 6m, no internal ATU. 4800 baud default CAT.
    public static let ts570S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true
    )

    /// Kenwood TH-D72A / TH-D72 - Dual-band handheld with APRS and GPS
    ///
    /// Frequency ranges and TX limits from Hamlib thd72.c (rx_range_list2 / tx_range_list2).
    /// Tuning steps from thd72tuningstep[]. CTCSS/DCS/duplex per hardware capability.
    /// Power is discrete: 5 W (High), 500 mW (Mid), 50 mW (Low) — see THD72Protocol.setPower().
    public static let thd72A = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,   // VMC/BC split supported per thd72_set_split_vfo
        powerControl: true,
        maxPower: 5,
        supportedModes: [.fm, .fmN, .am],
        frequencyRange: FrequencyRange(min: 118_000_000, max: 524_000_000),
        detailedFrequencyRanges: [
            // Airband receive (118–174 MHz per rx_range_list2)
            DetailedFrequencyRange(min: 118_000_000, max: 135_995_000, modes: [.am], canTransmit: false),
            DetailedFrequencyRange(min: 136_000_000, max: 143_999_999, modes: [.fm], canTransmit: false),
            // 2m TX band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.fm, .fmN], canTransmit: true, bandName: "2m"),
            // General VHF receive
            DetailedFrequencyRange(min: 148_000_001, max: 319_999_999, modes: [.fm], canTransmit: false),
            // 320–524 MHz receive band (per rx_range_list2)
            DetailedFrequencyRange(min: 320_000_000, max: 429_999_999, modes: [.fm], canTransmit: false),
            // 70cm TX band
            DetailedFrequencyRange(min: 430_000_000, max: 440_000_000, modes: [.fm, .fmN], canTransmit: true, bandName: "70cm"),
            // Upper UHF receive
            DetailedFrequencyRange(min: 440_000_001, max: 524_000_000, modes: [.fm], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: false,
        // TH-D72 does NOT expose a numeric S-meter via CAT. Hamlib
        // confirms (THD72_LEVEL_ALL includes RFPOWER, SQL, BALANCE,
        // VOXGAIN, VOXDELAY only); real-hardware testing 2026-05-29
        // showed `SM 0` returns `?` (unknown command). `BY <band>`
        // is available but reports a 0/1 busy flag, not S-units.
        supportsSignalStrength: false,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        availableTuningSteps: [5000, 6250, 10000, 12500, 15000, 20000, 25000, 30000, 50000, 100000]
    )

    // MARK: - v1.2.0 Group G — legacy HF still on the air

    /// Kenwood TS-450S — HF 100W transceiver (1991)
    ///
    /// Late-Cold-War-era HF-only transceiver (no 6m). Optional
    /// AT-450 internal ATU. Serial CAT runs at 4800 baud maximum,
    /// 8-N-2 with hardware handshake per Hamlib `rigs/kenwood/ts450s.c`.
    /// AM TX capped at 40 W per the same file's tx range list.
    public static let ts450S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 100_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_000, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasATU: true,   // Optional AT-450 internal ATU
        supportsSignalStrength: true
    )

    /// Kenwood TS-690S — HF + 6m 100W transceiver (1992)
    ///
    /// TS-450S sibling with 6m added — HF bands identical to
    /// TS-450, plus 50-54 MHz per Hamlib `rigs/kenwood/ts690.c`.
    /// Serial CAT: 4800 baud, 8-N-2, hardware handshake.
    public static let ts690S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 100_000, max: 54_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 100_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_000, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .am, .fm], canTransmit: false),
            // 6m — TS-690's differentiator vs TS-450
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.lsb, .usb, .cw, .cwR, .fm, .am, .rtty, .rttyR], canTransmit: true, bandName: "6m"),
        ],
        hasATU: true,
        supportsSignalStrength: true
    )

    /// Kenwood TS-940S — HF 100W flagship transceiver (1985)
    ///
    /// Kenwood's mid-1980s flagship HF. HF-only, 100 W, general-
    /// coverage RX 150 kHz – 30 MHz. Serial CAT: 4800 baud, 8-N-2,
    /// hardware handshake per Hamlib `rigs/kenwood/ts940.c`. Note
    /// Hamlib model name is `TS-940S` (with S suffix) even though
    /// the RIG_MODEL enum is `TS940`.
    public static let ts940S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        // TS940_ALL_MODES lacks CWR/RTTYR — Hamlib treats reverse
        // modes as data-mode variants that TS-940 doesn't expose.
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm],
        frequencyRange: FrequencyRange(min: 150_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 150_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .cw, .rtty], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_000, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .cw, .rtty], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasATU: false,  // No factory ATU; external AT-940 was optional
        supportsSignalStrength: true
    )

    /// Kenwood TS-950S — HF 150W flagship transceiver (1988)
    ///
    /// Kenwood's late-1980s flagship HF, upgraded from the TS-940.
    /// HF-only, 150 W. Serial CAT is unusual for the era: 4800
    /// baud, 8-N-2, **no** hardware handshake per Hamlib
    /// `rigs/kenwood/ts950.c`. Modes lack CW-reverse and
    /// RTTY-reverse (Hamlib TS950_ALL_MODES: AM, CW, USB, LSB, FM,
    /// RTTY only).
    public static let ts950S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 150,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm],
        frequencyRange: FrequencyRange(min: 150_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 150_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .cw, .rtty], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_000, max: 3_499_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .cw, .rtty], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_000, max: 6_999_999, modes: [.lsb, .usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .rtty], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .rtty], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .rtty, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .am], canTransmit: false),
        ],
        hasATU: true,   // TS-950S/SDX includes factory antenna tuner
        supportsSignalStrength: true
    )

    /// Kenwood TS-950SDX — DSP-equipped variant of TS-950S (1991)
    ///
    /// Same 150 W HF flagship as TS-950S but adds internal DSP
    /// filtering. CAT surface is identical. Cross-checked against
    /// Hamlib `rigs/kenwood/ts950.c` (`ts950sdx_caps`).
    public static let ts950SDX = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 150,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm],
        frequencyRange: FrequencyRange(min: 150_000, max: 30_000_000),
        detailedFrequencyRanges: ts950S.detailedFrequencyRanges,
        hasATU: true,
        supportsSignalStrength: true
    )

    // MARK: - v1.2.0 Group E — TM/TH-F family (CR-terminated CAT)

    /// Kenwood TM-D710(G) — dual-band FM mobile transceiver (2007+).
    ///
    /// 2m + 70cm amateur bands (50 W / 35 W), wideband RX 118-524 MHz.
    /// Modes: FM, FM-N, AM per Hamlib `rigs/kenwood/tmd710.c`
    /// TMD710_MODES / TMD710_MODES_TX. Cross-checked against
    /// `.cmdtrm = EOM_TH`, 57600 baud maximum.
    public static let tmd710 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 50,
        supportedModes: [.fm, .fmN, .am],
        frequencyRange: FrequencyRange(min: 118_000_000, max: 524_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 118_000_000, max: 143_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000,
                                    modes: [.fm, .fmN], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 148_000_001, max: 429_999_999,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000,
                                    modes: [.fm, .fmN], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 524_000_000,
                                    modes: [.fm, .fmN, .am], canTransmit: false),
        ],
        hasDualReceiver: true,
        hasATU: false,
        supportsSignalStrength: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        antennaCount: 1
    )

    /// Kenwood TM-V71(A) — dual-band FM mobile transceiver (2005+).
    ///
    /// Same protocol and RF footprint as the TM-D710 minus the
    /// D-STAR / TNC hardware. Same Hamlib backend (`tmd710.c`
    /// covers both).
    public static let tmv71 = tmd710

    /// Kenwood TH-F6A — tri-band FM/SSB HT (2m + 1.25m + 70cm).
    ///
    /// 5 W FM TX on three amateur bands; broadband RX 100 kHz –
    /// 1.3 GHz in FM / WFM / AM / LSB / USB / CW (non-FM modes are
    /// RX-only per Hamlib `THF6_MODES_TX`).
    public static let thf6a = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 5,
        supportedModes: [.fm, .fmN, .wfm, .am, .lsb, .usb, .cw],
        frequencyRange: FrequencyRange(min: 100_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 100_000, max: 143_999_999,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000,
                                    modes: [.fm], canTransmit: true, bandName: "2m"),
            DetailedFrequencyRange(min: 148_000_001, max: 221_999_999,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 222_000_000, max: 225_000_000,
                                    modes: [.fm], canTransmit: true, bandName: "1.25m"),
            DetailedFrequencyRange(min: 225_000_001, max: 429_999_999,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000,
                                    modes: [.fm], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 1_300_000_000,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
        ],
        hasATU: false,
        supportsSignalStrength: true,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        antennaCount: 1
    )

    /// Kenwood TH-F7E — European dual-band variant of TH-F6A.
    ///
    /// 2m + 70cm amateur TX only (no 1.25m allocation in Region 1).
    /// Same protocol as TH-F6A per Hamlib `thf7.c`.
    public static let thf7e = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: true,
        maxPower: 5,
        supportedModes: [.fm, .fmN, .wfm, .am, .lsb, .usb, .cw],
        frequencyRange: FrequencyRange(min: 100_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 100_000, max: 143_999_999,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 144_000_000, max: 146_000_000,
                                    modes: [.fm], canTransmit: true, bandName: "2m (R1)"),
            DetailedFrequencyRange(min: 146_000_001, max: 429_999_999,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
            DetailedFrequencyRange(min: 430_000_000, max: 440_000_000,
                                    modes: [.fm], canTransmit: true, bandName: "70cm (R1)"),
            DetailedFrequencyRange(min: 440_000_001, max: 1_300_000_000,
                                    modes: [.fm, .wfm, .am, .lsb, .usb, .cw],
                                    canTransmit: false),
        ],
        hasATU: false,
        supportsSignalStrength: true,
        region: .region1,
        supportsCTCSS: true,
        supportsDCS: true,
        supportsDuplex: true,
        antennaCount: 1
    )
}
