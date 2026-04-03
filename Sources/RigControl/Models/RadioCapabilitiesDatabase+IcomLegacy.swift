import Foundation

extension RadioCapabilitiesDatabase {

    // MARK: - Icom Legacy Mobile Transceivers

    /// Icom IC-706 - HF/6m/2m mobile transceiver
    public static let icomIC706 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .wfm],
        frequencyRange: FrequencyRange(min: 30_000, max: 200_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "2m"),
            // General coverage 2m receive
            DetailedFrequencyRange(min: 30_000_001, max: 200_000_000, modes: [.fm, .wfm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,  // Legacy mode commands, no filter byte
        powerUnits: .percentage
    )

    /// Icom IC-706MKII - HF/6m/2m mobile transceiver (enhanced)
    public static let icomIC706MKII = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .wfm],
        frequencyRange: FrequencyRange(min: 30_000, max: 200_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "2m"),
            // General coverage 2m receive
            DetailedFrequencyRange(min: 30_000_001, max: 200_000_000, modes: [.fm, .wfm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,  // Legacy mode commands, no filter byte
        powerUnits: .percentage
    )

    /// Icom IC-706MKIIG - HF/VHF/UHF mobile transceiver (adds UHF)
    public static let icomIC706MKIIG = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .wfm],
        frequencyRange: FrequencyRange(min: 30_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "2m"),
            // General coverage VHF/UHF receive
            DetailedFrequencyRange(min: 30_000_001, max: 429_999_999, modes: [.fm, .wfm, .am], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "70cm"),
            DetailedFrequencyRange(min: 450_000_001, max: 470_000_000, modes: [.fm, .wfm, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,  // Legacy mode commands, no filter byte
        powerUnits: .percentage
    )

    /// Icom IC-756 - HF/6m base station transceiver (original model)
    public static let icomIC756 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,  // Main/Sub receiver
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,  // IC-756 requires filter byte
        powerUnits: .percentage
    )

    /// Icom IC-7851 - HF/6m flagship transceiver with spectrum scope
    public static let icomIC7851 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,  // Main/Sub with spectrum scope
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-7850 HF/6m 200W flagship (50th Anniversary Limited Edition)
    public static let icomIC7850 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 200,  // 200W SSB/CW/RTTY/PSK/FM, 50W AM
        supportedModes: [.lsb, .usb, .cw, .cwR, .rtty, .rttyR, .am, .fm, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // General coverage receive
            DetailedFrequencyRange(min: 30_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            // HF bands
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .rttyR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .rttyR, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,  // Main/Sub receivers
        hasATU: true,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-910H - VHF/UHF satellite transceiver
    public static let icomIC910H = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .fmN],
        frequencyRange: FrequencyRange(min: 144_000_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "2m"),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "70cm"),
            // 23cm receive only
            DetailedFrequencyRange(min: 1_240_000_000, max: 1_300_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: false, bandName: "23cm RX"),
        ],
        hasDualReceiver: true,  // Main/Sub for satellite operation
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-970 VHF/UHF all-mode transceiver with satellite mode
    public static let icomIC970 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 45,  // 45W FM VHF, 40W FM UHF, 35W SSB/CW VHF, 30W SSB/CW UHF
        supportedModes: [.lsb, .usb, .cw, .cwR, .fm, .fmN],
        frequencyRange: FrequencyRange(min: 144_000_000, max: 1_300_000_000),
        detailedFrequencyRanges: [
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 150_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "2m"),
            // Receive gap
            DetailedFrequencyRange(min: 150_000_001, max: 429_999_999, modes: [.usb, .fm], canTransmit: false),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "70cm"),
            // Receive gap
            DetailedFrequencyRange(min: 450_000_001, max: 1_239_999_999, modes: [.usb, .fm], canTransmit: false),
            // 23cm band (optional UX-97 module)
            DetailedFrequencyRange(min: 1_240_000_000, max: 1_300_000_000, modes: [.usb, .cw, .cwR, .fm, .fmN], canTransmit: true, bandName: "23cm"),
        ],
        hasDualReceiver: true,  // Main/Sub for satellite operation
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-820H VHF/UHF dual-band satellite transceiver
    public static let icomIC820H = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 45,  // 45W FM VHF, 40W FM UHF, 35W SSB VHF, 30W SSB UHF
        supportedModes: [.lsb, .usb, .cw, .cwR, .fm],
        frequencyRange: FrequencyRange(min: 136_000_000, max: 450_000_000),
        detailedFrequencyRanges: [
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "2m"),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.usb, .cw, .cwR, .fm], canTransmit: true, bandName: "70cm"),
        ],
        hasDualReceiver: true,  // Main/Sub for satellite operation
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-2730 - VHF/UHF dual-band mobile transceiver
    public static let icomIC2730 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,  // No split operation
        powerControl: true,
        maxPower: 50,
        supportedModes: [.fm, .fmN],
        frequencyRange: FrequencyRange(min: 118_000_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // Airband receive
            DetailedFrequencyRange(min: 118_000_000, max: 136_000_000, modes: [.fm], canTransmit: false, bandName: "Airband"),
            // 2m band
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.fm, .fmN], canTransmit: true, bandName: "2m"),
            // 70cm band
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.fm, .fmN], canTransmit: true, bandName: "70cm"),
        ],
        hasDualReceiver: true,  // Dual band dual watch
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: false,  // FM only, no mode filter
        powerUnits: .percentage
    )

    // MARK: - Icom D-STAR Mobiles

    /// Icom ID-5100 - VHF/UHF D-STAR mobile transceiver
    public static let icomID5100 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 50,
        supportedModes: [.fm, .fmN, .am, .usb, .dataFM],  // D-STAR digital voice (DV) via dataFM
        frequencyRange: FrequencyRange(min: 118_000_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // Airband receive only
            DetailedFrequencyRange(min: 118_000_000, max: 136_000_000, modes: [.am], canTransmit: false, bandName: "Airband"),
            // 2m
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.fm, .fmN, .usb, .dataFM], canTransmit: true, bandName: "2m"),
            // 70cm
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.fm, .fmN, .usb, .dataFM], canTransmit: true, bandName: "70cm"),
        ],
        hasDualReceiver: true,  // Dual band dual watch
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom ID-4100 - VHF/UHF D-STAR mobile transceiver
    public static let icomID4100 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 65,
        supportedModes: [.fm, .fmN, .am, .usb, .dataFM],  // D-STAR digital voice (DV) via dataFM
        frequencyRange: FrequencyRange(min: 118_000_000, max: 470_000_000),
        detailedFrequencyRanges: [
            // Airband receive only
            DetailedFrequencyRange(min: 118_000_000, max: 136_000_000, modes: [.am], canTransmit: false, bandName: "Airband"),
            // 2m
            DetailedFrequencyRange(min: 144_000_000, max: 148_000_000, modes: [.fm, .fmN, .usb, .dataFM], canTransmit: true, bandName: "2m"),
            // 70cm
            DetailedFrequencyRange(min: 430_000_000, max: 450_000_000, modes: [.fm, .fmN, .usb, .dataFM], canTransmit: true, bandName: "70cm"),
        ],
        hasDualReceiver: true,  // Dual band dual watch
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    // MARK: - Icom Receivers

    /// Icom IC-R8600 - Wideband communications receiver
    public static let icomICR8600 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,  // Receiver only
        powerControl: false,  // No transmit power
        maxPower: 0,
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .fmN, .wfm],
        frequencyRange: FrequencyRange(min: 10_000, max: 3_000_000_000),
        detailedFrequencyRanges: [
            // Wideband coverage
            DetailedFrequencyRange(min: 10_000, max: 3_000_000_000, modes: [.lsb, .usb, .cw, .am, .fm, .fmN, .wfm], canTransmit: false, bandName: "Wideband"),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-R75 - HF communications receiver
    public static let icomICR75 = RigCapabilities(
        hasVFOB: false,  // Single VFO
        hasSplit: false,  // Receiver only
        powerControl: false,  // No transmit power
        maxPower: 0,
        supportedModes: [.lsb, .usb, .cw, .rtty, .am, .fm],
        frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
        detailedFrequencyRanges: [
            // HF general coverage
            DetailedFrequencyRange(min: 30_000, max: 60_000_000, modes: [.lsb, .usb, .cw, .rtty, .am, .fm], canTransmit: false, bandName: "HF"),
        ],
        hasDualReceiver: false,
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: false,  // Single VFO
        requiresModeFilter: true,
        powerUnits: .percentage
    )

    /// Icom IC-R9500 - Professional communications receiver
    public static let icomICR9500 = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,  // Receiver only
        powerControl: false,  // No transmit power
        maxPower: 0,
        supportedModes: [.lsb, .usb, .cw, .rtty, .rttyR, .am, .fm, .fmN, .wfm],
        frequencyRange: FrequencyRange(min: 5_000, max: 3_335_000_000),
        detailedFrequencyRanges: [
            // Wideband coverage
            DetailedFrequencyRange(min: 5_000, max: 3_335_000_000, modes: [.lsb, .usb, .cw, .rtty, .rttyR, .am, .fm, .fmN, .wfm], canTransmit: false, bandName: "Wideband"),
        ],
        hasDualReceiver: true,  // Dual receiver
        hasATU: false,
        supportsSignalStrength: true,
        requiresVFOSelection: true,
        requiresModeFilter: true,
        powerUnits: .percentage
    )

}
