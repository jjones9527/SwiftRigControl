import Foundation

extension RadioCapabilitiesDatabase.Elecraft {

    // MARK: - Elecraft Radios

    /// Elecraft K3 - HF/6m transceiver
    public static let k3 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        // Per Hamlib K3_MODES: CW | CWR | SSB | RTTY | RTTYR | FM
        // | AM | PKTUSB | PKTLSB. Elecraft K3 spec confirms FM is
        // supported for repeater work — was previously missing here
        // and from the 6m detailedFrequencyRange below.
        //
        // RTTY-R is in K3_MODES but not exposed yet: ElecraftProtocol
        // currently maps `.rtty` to `MD6` only; per the K3
        // Programmer's Reference the proper sequence is `MD6;DT2;`
        // for AFSK RTTY and `MD9;DT1;` for FSK RTTY-R. Plumbing the
        // DT sub-mode follow-up is tracked separately — once it
        // lands, add `.rttyR` here and on K3S/K4/KX2/KX3.
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .dataUSB, .dataLSB],
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
            // 6m band — K3 supports FM on 6m for VHF repeater work.
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown, .memoryToVFO],
        supportedFunctions: .elecraftKStandard
    )
    // MARK: - Remaining Elecraft Radios

    /// Elecraft K2 - HF transceiver
    public static let k2 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 15,  // 15W (100W with optional PA)
        // Per Hamlib `K2_MODES`: CW | CWR | SSB | PKTLSB | PKTUSB.
        // Verified on real hardware 2026-05-29 — AM, FM, and RTTY
        // requests are silently ignored (radio stays in previous
        // mode). PKT-{L,U}SB maps to data{L,U}SB.
        supportedModes: [.lsb, .usb, .cw, .cwR, .dataLSB, .dataUSB],
        frequencyRange: FrequencyRange(min: 500_000, max: 30_000_000),
        // Per Hamlib K2_MODES: CW | CWR | SSB | PKTLSB | PKTUSB.
        // No AM, FM, or RTTY support. Lower bands use LSB voice
        // and PKTLSB data; higher bands use USB voice and PKTUSB.
        detailedFrequencyRanges: [
            DetailedFrequencyRange(min: 500_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .cw, .cwR], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        // Antennas — K2 supports ANT 1/2 when the KAT-2 internal
        // tuner is installed; K2/100 with the external KAT100 also
        // exposes multiple antenna ports through the radio's CAT.
        // Per Hamlib K2_ANTS = RIG_ANT_1 | RIG_ANT_2. Operators
        // without the tuner installed will see a commandFailed at
        // runtime when calling selectAntenna — the radio rejects
        // the AN command without the optional hardware.
        antennaCount: 2,
        // VFO ops — K-series Elecrafts fall through to
        // kenwood_vfo_op in Hamlib. We expose only the
        // Kenwood-shared subset (UP/DN/BU/BD/MR) — TUNE is
        // model-specific (`SWT19` on K3, `SWT44` on KX3, etc.)
        // and not yet plumbed through ElecraftProtocol.
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown, .memoryToVFO],
        supportedFunctions: .elecraftKStandard
    )

    /// Elecraft K3S - HF/6m transceiver (enhanced K3)
    public static let k3S = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        // Per Hamlib K3_MODES (shared K3 mode list). K3S spec has
        // FM; previously missing. RTTY-R deferred — see K3's
        // doc-comment for the MD/DT sub-mode plumbing required.
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 500_000, max: 54_000_000),
        detailedFrequencyRanges: [
            // Similar to K3, see k3 definition above
            DetailedFrequencyRange(min: 500_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            // 6m band — K3S supports FM on 6m for VHF repeater work.
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown, .memoryToVFO],
        supportedFunctions: .elecraftKStandard
    )

    /// Elecraft K4 - HF/6m SDR transceiver
    public static let k4 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        // Per Hamlib K3_MODES (shared K-family list). K4 already
        // had FM. RTTY-R deferred — see K3's doc-comment for the
        // MD/DT sub-mode plumbing required.
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 500_000, max: 54_000_000),
        detailedFrequencyRanges: [
            // Similar to K3/K3S with enhanced SDR capabilities
            DetailedFrequencyRange(min: 500_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown, .memoryToVFO],
        supportedFunctions: .elecraftKStandard
    )

    /// Elecraft KX2 - Portable HF transceiver
    public static let kx2 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 12,  // 12W internal
        // Per Hamlib K3_MODES (the KX2 inherits the K-family mode
        // list in `kenwood/k3.c`). Frequency range tops at 30 MHz;
        // KX2 is HF-only on TX (no 6m), unlike Hamlib's KX2 range
        // which copy-pastes K3's 6m TX from the shared cap macros
        // — Elecraft's KX2 official spec is 80m–10m TX only.
        // `.dataLSB` added 2026-05-29 (was previously missing).
        // RTTY-R deferred — see K3 doc-comment.
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 500_000, max: 30_000_000),
        detailedFrequencyRanges: [
            // Similar to K2 but with updated features
            DetailedFrequencyRange(min: 500_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 30_000_000, modes: [.usb, .fm, .cw, .cwR, .am], canTransmit: false),
        ],
        hasDualReceiver: false,
        hasATU: true,
        supportsSignalStrength: true,
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown, .memoryToVFO],
        supportedFunctions: .elecraftKStandard
    )

    /// Elecraft KX3 - Portable HF/6m transceiver
    public static let kx3 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 15,  // 15W internal (100W with external PA)
        // Per Hamlib K3_MODES (the KX3 inherits the K-family mode
        // list). KX3 has full FM + 6m TX per Elecraft's spec.
        // RTTY-R deferred — see K3 doc-comment.
        supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .dataUSB, .dataLSB],
        frequencyRange: FrequencyRange(min: 500_000, max: 54_000_000),
        detailedFrequencyRanges: [
            // Similar to K3 but portable
            DetailedFrequencyRange(min: 500_000, max: 1_799_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 2_000_001, max: 3_499_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 4_000_001, max: 6_999_999, modes: [.lsb, .usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 7_000_000, max: 7_300_000, modes: [.lsb, .cw, .cwR, .rtty, .dataLSB], canTransmit: true, bandName: "40m"),
            DetailedFrequencyRange(min: 7_300_001, max: 10_099_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 10_100_000, max: 10_150_000, modes: [.cw, .cwR, .usb, .dataUSB], canTransmit: true, bandName: "30m"),
            DetailedFrequencyRange(min: 10_150_001, max: 13_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 14_350_001, max: 18_067_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 18_068_000, max: 18_168_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "17m"),
            DetailedFrequencyRange(min: 18_168_001, max: 20_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 21_000_000, max: 21_450_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "15m"),
            DetailedFrequencyRange(min: 21_450_001, max: 24_889_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 24_890_000, max: 24_990_000, modes: [.usb, .cw, .cwR, .rtty, .dataUSB], canTransmit: true, bandName: "12m"),
            DetailedFrequencyRange(min: 24_990_001, max: 27_999_999, modes: [.usb, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 28_000_000, max: 29_700_000, modes: [.usb, .cw, .cwR, .rtty, .fm, .dataUSB], canTransmit: true, bandName: "10m"),
            DetailedFrequencyRange(min: 29_700_001, max: 49_999_999, modes: [.usb, .fm, .cw, .cwR, .am], canTransmit: false),
            DetailedFrequencyRange(min: 50_000_000, max: 54_000_000, modes: [.usb, .cw, .cwR, .fm, .dataUSB], canTransmit: true, bandName: "6m"),
        ],
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown, .memoryToVFO],
        supportedFunctions: .elecraftKStandard
    )

}
