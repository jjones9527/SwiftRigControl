import Foundation

/// On/off radio function bits — toggles that don't take a value,
/// just `enabled: true/false`. Speech compressor, VOX, CTCSS,
/// front-panel lock, ATU enable, scope on/off, satellite mode,
/// etc.
///
/// This enum is a curated subset of Hamlib's `RIG_FUNC_*`
/// universe (rig.h:1261). Each case maps to a real wire command
/// in at least one shipping vendor implementation —
/// Hamlib-defined function bits that no vendor surfaces (FAGC,
/// ABM, ANL, etc.) are intentionally omitted.
///
/// Per-radio capability is gated by
/// ``RigCapabilities/supportedFunctions``. Calling
/// ``RigController/setFunction(_:enabled:)`` for a function the
/// radio doesn't claim throws
/// ``RigError/unsupportedOperation(_:)`` — there's no silent
/// no-op.
///
/// ## When this enum vs. a dedicated trait
///
/// Some on/off-shaped things already live on their own trait
/// (e.g. ``SupportsSplit``, ``SupportsRIT``) because they pair
/// with a query method that returns more than a bool. The
/// `RigFunction` surface is for bits that are truly boolean —
/// "is the compressor engaged?", "is the front panel locked?".
/// Don't reach for it when the right model is `setSplit(_:Bool)`
/// + `getSplitFrequency() -> UInt64`.
public enum RigFunction: String, Sendable, Codable, CaseIterable {
    /// Speech compressor on/off. Hamlib: `RIG_FUNC_COMP`.
    /// Common: every HF radio with a microphone.
    case compressor

    /// Voice-operated transmit (VOX). Hamlib: `RIG_FUNC_VOX`.
    case vox

    /// CTCSS tone encode (FM repeater access). Hamlib:
    /// `RIG_FUNC_TONE`.
    case ctcssTone

    /// CTCSS tone squelch (FM repeater RX). Hamlib:
    /// `RIG_FUNC_TSQL`.
    case ctcssSquelch

    /// Front-panel lock. Hamlib: `RIG_FUNC_LOCK`.
    case lock

    /// Internal antenna tuner enable. Hamlib: `RIG_FUNC_TUNER`.
    /// Distinct from triggering a tune cycle — see
    /// ``VFOOperation/tune``.
    case tuner

    /// Automatic notch filter (DSP). Hamlib: `RIG_FUNC_ANF`.
    case autoNotch

    /// Manual notch filter. Hamlib: `RIG_FUNC_MN`.
    case manualNotch

    /// Satellite operating mode (dual-VFO cross-band TX/RX).
    /// Hamlib: `RIG_FUNC_SATMODE`. Important for IC-9700,
    /// IC-9100.
    case satelliteMode

    /// Sidetone monitor — let the operator hear their own
    /// transmitted audio. Hamlib: `RIG_FUNC_MON`.
    case monitor

    /// Auto frequency control (FM). Hamlib: `RIG_FUNC_AFC`.
    case autoFrequencyControl

    /// Beat canceller (notch out a CW or beat tone). Hamlib:
    /// `RIG_FUNC_BC`. Kenwood-specific in practice.
    case beatCancel

    /// Second-stage noise blanker. Hamlib: `RIG_FUNC_NB2`.
    case noiseBlanker2

    /// Audio peak filter (CW). Hamlib: `RIG_FUNC_APF`.
    case audioPeakFilter

    /// Reverse split / duplex on V/UHF. Hamlib: `RIG_FUNC_REV`.
    case reverseSplit

    /// Dual watch / sub-receiver. Hamlib: `RIG_FUNC_DUAL_WATCH`.
    case dualWatch

    /// Diversity reception. Hamlib: `RIG_FUNC_DIVERSITY`.
    case diversity

    /// RX audio mute. Hamlib: `RIG_FUNC_MUTE`.
    case mute

    /// Spectrum scope on/off. Hamlib: `RIG_FUNC_SCOPE`.
    /// Distinct from scope *configuration*; this is just the
    /// power button.
    case scope

    /// Scan auto-resume. Hamlib: `RIG_FUNC_RESUME`.
    case scanResume

    /// Voice-controlled squelch (Icom VSC). Hamlib:
    /// `RIG_FUNC_VSC`.
    case voiceSquelch
}
