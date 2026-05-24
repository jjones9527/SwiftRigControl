import Foundation

// Per-radio "what we know works" function-bit presets, derived
// from Hamlib's per-radio `has_set_func`/`has_get_func` masks.
// Filtered to bits that map to our `RigFunction` enum (Hamlib
// has ~50 bits; we expose 21).

extension Set where Element == RigFunction {

    /// IC-7600 function set. Matches Hamlib `IC7600_FUNCS`
    /// (rigs/icom/ic7600.c:40) filtered to bits we expose:
    /// compressor, VOX, CTCSS tone/squelch, monitor, manual
    /// notch, auto notch, lock, tuner, APF, dual watch.
    public static let icomIC7600Funcs: Set<RigFunction> = [
        .compressor, .vox, .ctcssTone, .ctcssSquelch,
        .monitor, .manualNotch, .autoNotch, .lock,
        .tuner, .audioPeakFilter, .dualWatch,
    ]

    /// IC-7100 function set. Matches Hamlib `IC7100_FUNC_ALL`
    /// (rigs/icom/ic7100.c:53) plus RIG_FUNC_RESUME.
    public static let icomIC7100Funcs: Set<RigFunction> = [
        .autoNotch, .ctcssTone, .ctcssSquelch, .compressor,
        .vox, .autoFrequencyControl, .voiceSquelch,
        .manualNotch, .lock, .scope, .tuner, .scanResume,
    ]

    /// IC-7300 / IC-7610 / IC-705 / IC-7760 / IC-7300MK2.
    /// Matches Hamlib `IC7300_FUNCS` (rigs/icom/ic7300.c:50).
    public static let icomIC7300Funcs: Set<RigFunction> = [
        .compressor, .vox, .ctcssTone, .ctcssSquelch,
        .monitor, .manualNotch, .autoNotch, .lock,
        .scope, .tuner,
    ]

    /// IC-9700 function set. Matches Hamlib `IC9700_FUNCS`
    /// (rigs/icom/ic7300.c:202). Adds SATMODE, DUAL_WATCH, AFC;
    /// drops TUNER (no internal ATU).
    public static let icomIC9700Funcs: Set<RigFunction> = [
        .compressor, .vox, .ctcssTone, .ctcssSquelch,
        .monitor, .manualNotch, .autoNotch, .lock,
        .scope, .satelliteMode, .dualWatch,
        .autoFrequencyControl,
    ]

    /// Kenwood TS-590S/SG, TS-890S, TS-990S — typical HF set.
    /// Matches the common subset of `kenwood_set_func` (COMP,
    /// VOX, TONE, TSQL, LOCK, TUNER, ANF, BC).
    public static let kenwoodHFStandard: Set<RigFunction> = [
        .compressor, .vox, .ctcssTone, .ctcssSquelch,
        .lock, .tuner, .autoNotch, .beatCancel,
    ]

    /// Yaesu newcat modern HF — FT-991, FT-710, FTDX series.
    /// Matches the common subset of `newcat_set_func`.
    public static let yaesuHFStandard: Set<RigFunction> = [
        .compressor, .vox, .ctcssTone, .ctcssSquelch,
        .lock, .tuner, .autoNotch, .manualNotch,
        .monitor, .noiseBlanker2,
    ]

    /// Elecraft K3 / K3S / K4 typical set.
    public static let elecraftKStandard: Set<RigFunction> = [
        .compressor, .vox, .ctcssTone, .ctcssSquelch,
        .lock, .audioPeakFilter, .dualWatch, .diversity,
    ]
}
