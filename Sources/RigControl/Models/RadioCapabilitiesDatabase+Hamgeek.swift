import Foundation

extension RadioCapabilitiesDatabase.Hamgeek {
    /// Hamgeek uSDX TS-480-subset transceiver, cross-referenced with Hamlib
    /// `hamgeek.c` backend version 20260423.0.
    public static let usdx = RigCapabilities(
        hasVFOB: false,
        hasSplit: false,
        powerControl: false,
        maxPower: 5,
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 1_800_000, max: 30_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 1_800_000, max: 1_999_999, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 3_999_999, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 5_351_000, max: 5_367_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "60m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.lsb, .usb, .cw, .cwR, .am, .fm, .dataUSB, .dataLSB], canTransmit: true, bandName: "10m")
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: false,
        supportsRIT: false,
        supportsXIT: false,
        availableTuningSteps: [10, 100, 1_000, 5_000, 10_000, 100_000, 1_000_000]
    )
}
