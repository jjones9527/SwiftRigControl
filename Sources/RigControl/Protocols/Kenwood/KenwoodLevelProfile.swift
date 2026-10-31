import Foundation

/// Per-model wire formats and scales for Kenwood level commands.
///
/// Kenwood-family radios share command names but not their formats or
/// ranges: Hamlib has a different encoding of AGC, the attenuator,
/// squelch and the secondary levels for almost every backend
/// (`kenwood.c`, `ts590.c`, `ts890s.c`, `ts2000.c`, `ts480.c`). The
/// presets below were taken from what Hamlib actually sends for each
/// model, captured with `Scripts/hamlib-set-matrix.py`, and from each
/// model's Hamlib caps (`rigctl -m <model> -u`).
///
/// ``generic`` keeps the earlier behavior for radios where Hamlib's own
/// generic code is not a credible reference (its AGC is
/// `GT%03d` of `84 × RIG_AGC`, which gives 420 for "medium"), except VOX
/// gain, which is 0–9 as Hamlib sends for every Kenwood. See
/// `Documentation/HAMLIB_COMMAND_AUDIT.md`.
///
/// ```swift
/// let kenwood = KenwoodProtocol(
///     transport: transport,
///     capabilities: RadioCapabilitiesDatabase.Kenwood.ts590SG,
///     modeStyle: .dataSubMode,
///     levelProfile: .ts590SG
/// )
/// ```
public struct KenwoodLevelProfile: Sendable, Equatable {

    /// How AGC is set and read.
    public enum AGCEncoding: Sendable, Equatable {
        /// `GT` with a `width`-digit code per speed. A read is mapped
        /// back to the nearest listed speed at or above it.
        case gt(width: Int, codes: [AGCSpeed: Int])
        /// `GC` with one digit (TS-890S, Hamlib `ts890s.c:63-90`).
        case gc(codes: [AGCSpeed: Int])
    }

    /// AGC encoding.
    public internal(set) var agc: AGCEncoding

    /// Attenuator steps in dB; `RA` carries the 1-based index of the
    /// step (Hamlib `kenwood_set_level` RIG_LEVEL_ATT, `kenwood.c:3560`).
    /// Empty when the radio has no CAT-controlled attenuator.
    public internal(set) var attenuatorSteps: [Int]

    /// Digits in the `RA` code: 2, or 1 on the TS-890S (`kenwood.c:3562`).
    public internal(set) var attenuatorDigits: Int

    /// Full scale of `RG` RF gain: 255, or 100 on the TS-480.
    public internal(set) var rfGainMax: Int

    /// `SQ0nnn` (receiver digit) or `SQnnn` (TS-890S, `ts890s.c:92`).
    public internal(set) var squelchHasReceiverDigit: Bool

    /// Noise blanker command: `NB` + 0/1, or `NB1` + 0/1 on the TS-890S
    /// (NB1 as distinct from NB2).
    public internal(set) var noiseBlankerPrefix: String

    /// Full scale of `ML` monitor gain: 20 on the TS-590SG, 9 on the
    /// TS-590S / TS-2000 / TS-480 (`ts590.c` RIG_LEVEL_MONITOR_GAIN).
    public internal(set) var monitorGainMax: Int

    /// Full scale of `VG` VOX gain: 9 on every Kenwood Hamlib drives
    /// (`kenwood.c` RIG_LEVEL_VOXGAIN, `val * 9`).
    public internal(set) var voxGainMax: Int

    /// Whether `PL` carries two 3-digit values (processor in / out), as
    /// Hamlib sends on the TS-590 / TS-2000 / TS-480 / TS-990S / TX-500.
    public internal(set) var compressorHasTwoValues: Bool

    /// Full scale of each `PL` value: 100, or 255 on the TS-990S.
    public internal(set) var compressorMax: Int

    /// Full scale of the `RL` noise-reduction level, or `nil` if the
    /// radio has no level and `NR` is on/off only (`ts590.c`: 0-9).
    public internal(set) var noiseReductionLevelMax: Int?

    /// How the `LK` lock command carries its on/off value.
    public enum LockForm: Sendable, Equatable {
        /// `LK0` / `LK1` (Hamlib `kenwood_set_func`).
        case single
        /// `LK00` / `LK10` (TS-590S/SG, `ts590.c:486`).
        case trailingZero
        /// `LK00` / `LK11` (TS-480, TS-2000; `ts480.c:271`, `ts2000.c:340`).
        case doubled
    }

    /// How the antenna tuner is switched on and off (not a tune cycle,
    /// which is `AC111`).
    public enum TunerForm: Sendable, Equatable {
        /// `AC100` / `AC110`: TX tuner on, no tune (Hamlib `kenwood.c` RIG_FUNC_TUNER).
        case standard
        /// `AC000` / `AC110`: RX and TX tuner together (TS-590, `ts590.c:490`).
        case receiveAndTransmit
        /// `AC 00` / `AC 10` (TS-570, `ts570.c:266`).
        case ts570
        /// `ZZTU0` / `ZZTU1` (PowerSDR / Thetis, `flex6xxx.c:1170`).
        case powerSDR
    }

    /// `LK` lock form.
    public internal(set) var lockForm: LockForm = .single

    /// Antenna tuner on/off form.
    public internal(set) var tunerForm: TunerForm = .standard

    /// VOX on/off command: `VX`, or `ZZVE` on PowerSDR / Thetis
    /// (`flex6xxx.c:1162`).
    public internal(set) var voxPrefix: String = "VX"

    /// Behavior before the Hamlib command audit; used for radios without
    /// a credible Hamlib reference.
    public static let generic = KenwoodLevelProfile(
        agc: .gt(width: 3, codes: [.off: 0, .fast: 1, .medium: 2, .slow: 3]),
        attenuatorSteps: [6, 12, 18],
        attenuatorDigits: 2,
        rfGainMax: 255,
        squelchHasReceiverDigit: true,
        noiseBlankerPrefix: "NB",
        monitorGainMax: 100,
        voxGainMax: 9,
        compressorHasTwoValues: false,
        compressorMax: 100,
        noiseReductionLevelMax: nil
    )

    /// TS-590S (Hamlib `ts590.c`): `GT` 2 digits, 0 / 5 / 10 / 20.
    public static let ts590S = KenwoodLevelProfile(
        agc: .gt(width: 2, codes: [.off: 0, .fast: 5, .medium: 10, .slow: 20]),
        attenuatorSteps: [12],
        attenuatorDigits: 2,
        rfGainMax: 255,
        squelchHasReceiverDigit: true,
        noiseBlankerPrefix: "NB",
        monitorGainMax: 9,
        voxGainMax: 9,
        compressorHasTwoValues: true,
        compressorMax: 100,
        noiseReductionLevelMax: 9
    ).with {
        $0.lockForm = .trailingZero
        $0.tunerForm = .receiveAndTransmit
    }

    /// TS-590SG: as the TS-590S, with monitor gain 0–20.
    public static let ts590SG = ts590S.with { $0.monitorGainMax = 20 }

    /// TS-2000 and SDR-Console (Hamlib `ts2000.c`): `GT` 3 digits.
    public static let ts2000 = ts590S.with {
        $0.agc = .gt(width: 3, codes: [.off: 0, .fast: 5, .medium: 10, .slow: 20])
        $0.lockForm = .doubled
        $0.tunerForm = .standard
    }

    /// TS-480HX / TS-480SAT (Hamlib `ts480.c`): fast / slow only, RF 0–100.
    public static let ts480 = ts590S.with {
        $0.agc = .gt(width: 3, codes: [.off: 0, .fast: 1, .slow: 2])
        $0.rfGainMax = 100
        $0.lockForm = .doubled
        $0.tunerForm = .standard
    }

    /// TS-890S (Hamlib `ts890s.c`): `GC`, 1-digit `RA`, `SQnnn`, `NB1n`.
    public static let ts890S = generic.with {
        $0.agc = .gc(codes: [.off: 0, .slow: 1, .medium: 2, .fast: 3])
        $0.attenuatorDigits = 1
        $0.squelchHasReceiverDigit = false
        $0.noiseBlankerPrefix = "NB1"
    }

    /// TS-990S: 6 / 12 / 18 dB, `PL` two values on a 0–255 scale.
    public static let ts990S = generic.with {
        $0.compressorHasTwoValues = true
        $0.compressorMax = 255
    }

    /// TS-570D / TS-570S: a single 18 dB attenuator.
    public static let ts570 = generic.with {
        $0.attenuatorSteps = [18]
        $0.tunerForm = .ts570
    }

    /// Lab599 TX-500: a single 20 dB attenuator, `PL` two values.
    public static let tx500 = generic.with {
        $0.attenuatorSteps = [20]
        $0.compressorHasTwoValues = true
    }

    /// OpenHPSDR PiHPSDR: a single 20 dB attenuator (Hamlib caps).
    public static let piHPSDR = generic.with { $0.attenuatorSteps = [20] }

    /// Radios with no CAT attenuator in Hamlib (TS-450S, TS-690S,
    /// TS-850S, TS-940S, Flex 6000, PowerSDR, Thetis).
    public static let noAttenuator = generic.with { $0.attenuatorSteps = [] }

    /// PowerSDR and Thetis: no attenuator; VOX and tuner on the `ZZ`
    /// command set (Hamlib `flex6xxx.c:1162-1170`).
    public static let powerSDR = noAttenuator.with {
        $0.voxPrefix = "ZZVE"
        $0.tunerForm = .powerSDR
    }

    /// Memberwise initializer.
    ///
    /// - Parameters: See the matching properties.
    public init(
        agc: AGCEncoding,
        attenuatorSteps: [Int],
        attenuatorDigits: Int,
        rfGainMax: Int,
        squelchHasReceiverDigit: Bool,
        noiseBlankerPrefix: String,
        monitorGainMax: Int,
        voxGainMax: Int,
        compressorHasTwoValues: Bool,
        compressorMax: Int,
        noiseReductionLevelMax: Int?
    ) {
        self.agc = agc
        self.attenuatorSteps = attenuatorSteps
        self.attenuatorDigits = attenuatorDigits
        self.rfGainMax = rfGainMax
        self.squelchHasReceiverDigit = squelchHasReceiverDigit
        self.noiseBlankerPrefix = noiseBlankerPrefix
        self.monitorGainMax = monitorGainMax
        self.voxGainMax = voxGainMax
        self.compressorHasTwoValues = compressorHasTwoValues
        self.compressorMax = compressorMax
        self.noiseReductionLevelMax = noiseReductionLevelMax
    }

    func with(_ change: (inout KenwoodLevelProfile) -> Void) -> KenwoodLevelProfile {
        var copy = self
        change(&copy)
        return copy
    }
}
