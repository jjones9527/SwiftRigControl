import Foundation

/// Database of detailed radio capabilities for all supported models.
///
/// This database contains accurate frequency ranges, transmit capabilities, and supported modes
/// for each radio model. Data is sourced from manufacturer specifications and operator manuals.
///
/// All frequencies are in Hz. Frequency ranges marked with `canTransmit: false` are receive-only.
public struct RadioCapabilitiesDatabase {

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
            // HF General coverage receive only
            DetailedFrequencyRange(min: 30_000, max: 74_799_999, modes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "6m"),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "2m"),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "70cm"),
            // 23cm band
            DetailedFrequencyRange(min: 1_240_000_000, max: 1_300_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN, .dataUSB], canTransmit: true, bandName: "23cm"),
        ],
        hasDualReceiver: true,
        hasATU: false,
        supportsSignalStrength: true
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
        supportsSignalStrength: true
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
        supportsSignalStrength: true
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
        supportsSignalStrength: true
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
        supportsSignalStrength: true
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
        supportsSignalStrength: true
    )

    // MARK: - Yaesu Radios

    /// Yaesu FTDX-10 - HF/6m transceiver
    public static let yaesuFTDX10 = RigCapabilities(
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
        supportsSignalStrength: true
    )

    /// Yaesu FT-991A - HF/VHF/UHF all-mode transceiver
    public static let yaesuFT991A = RigCapabilities(
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
        supportsSignalStrength: true
    )

    // MARK: - Kenwood Radios

    /// Kenwood TS-590SG - HF/6m transceiver
    public static let kenwoodTS590SG = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive only
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
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 60_000_000, modes: [.usb, .fm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true
    )

    // MARK: - Elecraft Radios

    /// Elecraft K3 - HF/6m transceiver
    public static let elecraftK3 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .rtty, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 500_000, max: 54_000_000),
        detailedFrequencyRanges: [
            // General coverage receive only
            DetailedFrequencyRange(min: 500_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 160m band
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            // General coverage receive
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 80m band
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            // General coverage receive
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // 40m band
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            // General coverage receive
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 30m band
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            // General coverage receive
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 20m band
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            // General coverage receive
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 17m band
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            // General coverage receive
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 15m band
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            // General coverage receive
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 12m band
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            // General coverage receive
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 10m band
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "10m"),
            // General coverage receive
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 6m band
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true
    )

    // MARK: - Generic Fallback

    /// Generic HF transceiver with basic capabilities
    public static let genericHF = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am],
        frequencyRange: FrequencyRange(min: 1_800_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_800_000, max: 30_000_000, modes: [.lsb, .usb, .cw, .rtty, .am], canTransmit: true),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true
    )
}
