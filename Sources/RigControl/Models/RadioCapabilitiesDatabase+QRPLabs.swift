import Foundation

extension RadioCapabilitiesDatabase.QRPLabs {
    /// QMX five-band SDR transceiver. Hamlib's current backend exposes the
    /// 4–14 MHz CAT tuning span and only CW/CW-R plus SSB audio-data modes.
    public static let qmx = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: false,
        maxPower: 6,
        supportedModes: [.lsb, .usb, .cw, .cwR],
        frequencyRange: FrequencyRange(min: 4_000_000, max: 14_000_000),
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 4_000_000, max: 14_000_000,
                                   modes: [.lsb, .usb, .cw, .cwR],
                                   canTransmit: true)
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: false,
        supportsRIT: false,
        supportsXIT: false,
        supportsRFPowerMeter: true,
        supportsSWRMeter: true
    )
}
