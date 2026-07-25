import Foundation

extension RadioCapabilitiesDatabase.Flex {

    // MARK: - Common Flex 6000 / PowerSDR / Thetis frequency map
    //
    // All three share the same RF coverage in Hamlib `flex6xxx.c`:
    //   RX: 30 kHz – 77 MHz, 135 – 165 MHz
    //   TX: all HF amateur bands, 6 m, 2 m (Region-1/2 verified)
    // Modes: CW, SSB (LSB/USB), AM, FM, PKT-LSB (DATA-LSB),
    //        PKT-USB (DATA-USB).

    private static let flexFrequencyRanges: [DetailedFrequencyRange] = [
        // Wideband HF receive (general coverage)
        DetailedFrequencyRange(min: 30_000, max: 1_799_999,
                                modes: [.lsb, .usb, .cw, .am], canTransmit: false),
        // 160m
        DetailedFrequencyRange(min: 1_800_000, max: 2_000_000,
                                modes: [.lsb, .cw, .rtty, .dataLSB],
                                canTransmit: true, bandName: "160m"),
        DetailedFrequencyRange(min: 2_000_001, max: 3_499_999,
                                modes: [.lsb, .usb, .cw, .am], canTransmit: false),
        // 80m
        DetailedFrequencyRange(min: 3_500_000, max: 4_000_000,
                                modes: [.lsb, .cw, .rtty, .dataLSB],
                                canTransmit: true, bandName: "80m"),
        DetailedFrequencyRange(min: 4_000_001, max: 6_999_999,
                                modes: [.lsb, .usb, .cw, .am], canTransmit: false),
        // 40m
        DetailedFrequencyRange(min: 7_000_000, max: 7_300_000,
                                modes: [.lsb, .cw, .rtty, .dataLSB],
                                canTransmit: true, bandName: "40m"),
        DetailedFrequencyRange(min: 7_300_001, max: 10_099_999,
                                modes: [.usb, .cw, .am], canTransmit: false),
        // 30m
        DetailedFrequencyRange(min: 10_100_000, max: 10_150_000,
                                modes: [.cw, .usb, .rtty, .dataUSB],
                                canTransmit: true, bandName: "30m"),
        DetailedFrequencyRange(min: 10_150_001, max: 13_999_999,
                                modes: [.usb, .cw, .am], canTransmit: false),
        // 20m
        DetailedFrequencyRange(min: 14_000_000, max: 14_350_000,
                                modes: [.usb, .cw, .rtty, .dataUSB],
                                canTransmit: true, bandName: "20m"),
        DetailedFrequencyRange(min: 14_350_001, max: 18_067_999,
                                modes: [.usb, .cw, .am], canTransmit: false),
        // 17m
        DetailedFrequencyRange(min: 18_068_000, max: 18_168_000,
                                modes: [.usb, .cw, .rtty, .dataUSB],
                                canTransmit: true, bandName: "17m"),
        DetailedFrequencyRange(min: 18_168_001, max: 20_999_999,
                                modes: [.usb, .cw, .am], canTransmit: false),
        // 15m
        DetailedFrequencyRange(min: 21_000_000, max: 21_450_000,
                                modes: [.usb, .cw, .rtty, .dataUSB],
                                canTransmit: true, bandName: "15m"),
        DetailedFrequencyRange(min: 21_450_001, max: 24_889_999,
                                modes: [.usb, .cw, .am], canTransmit: false),
        // 12m
        DetailedFrequencyRange(min: 24_890_000, max: 24_990_000,
                                modes: [.usb, .cw, .rtty, .dataUSB],
                                canTransmit: true, bandName: "12m"),
        DetailedFrequencyRange(min: 24_990_001, max: 27_999_999,
                                modes: [.usb, .cw, .am], canTransmit: false),
        // 10m
        DetailedFrequencyRange(min: 28_000_000, max: 29_700_000,
                                modes: [.usb, .cw, .fm, .am, .rtty, .dataUSB],
                                canTransmit: true, bandName: "10m"),
        DetailedFrequencyRange(min: 29_700_001, max: 49_999_999,
                                modes: [.usb, .fm, .am], canTransmit: false),
        // 6m
        DetailedFrequencyRange(min: 50_000_000, max: 54_000_000,
                                modes: [.usb, .lsb, .cw, .fm, .am, .dataUSB],
                                canTransmit: true, bandName: "6m"),
        DetailedFrequencyRange(min: 54_000_001, max: 76_999_999,
                                modes: [.fm, .am], canTransmit: false),
        // 2m (135–165 MHz wideband receive, 144–148 MHz TX)
        DetailedFrequencyRange(min: 135_000_000, max: 143_999_999,
                                modes: [.fm, .am], canTransmit: false),
        DetailedFrequencyRange(min: 144_000_000, max: 148_000_000,
                                modes: [.usb, .cw, .fm, .fmN, .dataUSB],
                                canTransmit: true, bandName: "2m"),
        DetailedFrequencyRange(min: 148_000_001, max: 165_000_000,
                                modes: [.fm, .am], canTransmit: false),
    ]

    /// Flex 6000-series — SmartSDR-driven SDR transceivers.
    ///
    /// Covers the 6300, 6400, 6500, 6600, and 6700 variants. All
    /// expose the same Kenwood-derived CAT surface on TCP port
    /// 4992 (SmartSDR's TCP CAT bridge). Cross-checked against
    /// Hamlib `kenwood/flex6xxx.c` (`F6K_*` macros).
    ///
    /// - F6K_MODES: CW, SSB, AM, FM, PKT-LSB (DATA-LSB),
    ///   PKT-USB (DATA-USB).
    /// - F6K_LEVEL_ALL: SLOPE_HIGH, SLOPE_LOW, KEYSPD, RFPOWER.
    /// - F6K_ANTS: three antenna jacks per Hamlib.
    /// - 100 W HF/6 m, 100 W 2 m.
    public static let flex6000 = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .dataLSB, .dataUSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 165_000_000),
        detailedFrequencyRanges: flexFrequencyRanges,
        hasDualReceiver: true,    // SmartSDR supports multiple slice receivers
        hasATU: true,             // 6300/6400 ATU optional; 6500/6600/6700 ATU standard
        supportsSignalStrength: true,
        availableTuningSteps: [1, 10, 100, 1000, 5000, 10000, 100000],
        supportsCWKeyer: true,    // KS / KEYSPD
        antennaCount: 3           // RIG_ANT_1 | RIG_ANT_2 | RIG_ANT_3
    )

    /// PowerSDR (FlexRadio/Apache Labs) — drives FlexRadio
    /// 1500/3000/5000A and Apache Labs ANAN HPSDR boxes via a
    /// virtual serial CAT bridge. Cross-checked against Hamlib
    /// `kenwood/flex6xxx.c` (`POWERSDR_*` macros).
    ///
    /// PowerSDR's CAT surface is a superset of Flex 6000:
    /// adds VOX, SQL, NB, ANF, MUTE, RIT, XIT, TUNER function
    /// bits and a richer level set (mic gain, VOX gain, AGC, RF,
    /// IF, S-meter, SWR, RF-power-meter, RF-power-meter-watts).
    public static let powerSDR = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .dataLSB, .dataUSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 165_000_000),
        detailedFrequencyRanges: flexFrequencyRanges,
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        availableTuningSteps: [1, 10, 100, 1000, 5000, 10000, 100000],
        supportsRFPowerMeter: true,
        supportsSWRMeter: true,
        supportsCWKeyer: true,
        antennaCount: 3,
        // Hamlib `POWERSDR_VFO_OP` — band step + tuning step.
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown],
        // Hamlib `POWERSDR_FUNC_ALL`: VOX, SQL, NB, ANF, MUTE,
        // RIT, XIT, TUNER. SQL / NB / RIT / XIT live on dedicated
        // traits (`SupportsSquelch`, `SupportsNoiseBlanker`,
        // `SupportsRIT`, `SupportsXIT`), so only the pure on/off
        // bits are listed here.
        supportedFunctions: [.vox, .autoNotch, .mute, .tuner]
    )

    /// Thetis (TAPR) — open-source fork of PowerSDR maintained by
    /// TAPR for HPSDR / ANAN hardware. Shares the same CAT surface
    /// as PowerSDR. Cross-checked against Hamlib
    /// `kenwood/flex6xxx.c` (`Thetis` model).
    public static let thetis = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .dataLSB, .dataUSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 165_000_000),
        detailedFrequencyRanges: flexFrequencyRanges,
        hasDualReceiver: true,
        hasATU: true,
        supportsSignalStrength: true,
        availableTuningSteps: [1, 10, 100, 1000, 5000, 10000, 100000],
        supportsRFPowerMeter: true,
        supportsSWRMeter: true,
        supportsCWKeyer: true,
        antennaCount: 3,
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown],
        supportedFunctions: [.vox, .autoNotch, .mute, .tuner]
    )

    // MARK: - v1.2.0 Group I — TS-2000-emulation SDR clients

    /// SDR-Console (Simon Brown, SDR Radio) — Windows-first SDR
    /// client that drives external SDR hardware via a TS-2000-style
    /// Kenwood CAT emulation, typically bridged through a virtual
    /// serial port. Cross-checked against Hamlib
    /// `rigs/kenwood/ts2000.c` (`RIG_MODEL_SDRCONSOLE`) — the
    /// Hamlib backend registers SDR-Console as a distinct model
    /// even though the wire protocol is a TS-2000 subset.
    ///
    /// The exposed CAT surface is intentionally narrow: get/set
    /// frequency, mode, AGC, S-meter, slope-high/low IF filter,
    /// meter switching. SDR-Console does not expose PTT-off-air
    /// through CAT — RIG_LEVEL_SET is NONE per Hamlib. RF power
    /// depends on the underlying hardware; we advertise 100 W as
    /// a conservative upper bound and let the operator constrain
    /// via the SDR-Console UI.
    public static let sdrConsole = RigCapabilities(
        hasVFOB: true,
        hasSplit: false,
        powerControl: false,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .dataLSB, .dataUSB],
        frequencyRange: FrequencyRange(min: 30_000, max: 165_000_000),
        detailedFrequencyRanges: flexFrequencyRanges,
        hasATU: false,
        supportsSignalStrength: true,
        // SDRCONSOLE_LEVEL_GET includes AGC, STRENGTH, METER,
        // SLOPE_HIGH, SLOPE_LOW; SET is NONE per Hamlib ts2000.c.
        antennaCount: 1
    )

    /// PiHPSDR (OpenHPSDR) — open-source software SDR client
    /// running on Raspberry Pi (and desktop Linux), driving HPSDR
    /// and ANAN hardware. Exposes a TS-2000-derived Kenwood CAT
    /// surface. Cross-checked against Hamlib
    /// `rigs/kenwood/pihpsdr.c` (`RIG_MODEL_HPSDR`) — the header
    /// comment explicitly cites the file as "TS-2000 Emulation
    /// (derived from ts2000.c)".
    ///
    /// Full-transmit HF + 6m + 2m per band-plan tables. PiHPSDR
    /// exposes a rich feature set: TONE/TSQL/BC/NB/NR/ANF/COMP,
    /// preamp, attenuator, mic-gain, CW pitch, VOX delay, break-in
    /// delay, meter switching. 100 W HF/6m max per the tx_range
    /// table; AM TX capped at 25 W per Hamlib.
    public static let pihpsdr = RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .am, .fm, .rtty],
        frequencyRange: FrequencyRange(min: 30_000, max: 165_000_000),
        detailedFrequencyRanges: flexFrequencyRanges,
        hasATU: false,
        supportsSignalStrength: true,
        supportsCTCSS: true,   // PIHPSDR_FUNC_ALL: TONE + TSQL
        supportsDCS: false,
        supportsRFPowerMeter: true,
        supportsCompMeter: true,
        supportsCWKeyer: true,
        antennaCount: 2,       // PIHPSDR_ANTS = ANT_1 | ANT_2
        supportedVFOOperations: [.stepUp, .stepDown, .bandUp, .bandDown],
        // PIHPSDR_FUNC_ALL: TONE, TSQL, BC (beat cancel), NB, NR,
        // ANF, COMP. CTCSS lives on `SupportsCTCSS`; NB/NR/ANF
        // live on dedicated traits; only the pure on/off bits
        // land here.
        supportedFunctions: [.autoNotch, .beatCancel]
    )
}
