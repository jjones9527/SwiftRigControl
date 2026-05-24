import Foundation

/// Compound VFO operations — single-action commands like
/// "swap A↔B" or "tune the ATU" that don't fit the typical
/// get/set pattern.
///
/// This enum mirrors Hamlib's `RIG_OP_*` bitfield (rig.h:762).
/// Each case names what the operation *does* from the operator's
/// perspective; on the wire each vendor translates differently
/// (CI-V 0x07 sub-commands for Icom, ASCII tokens for the text
/// protocols). Per-radio capability is gated by
/// ``RigCapabilities/supportedVFOOperations``.
///
/// Not every operation is universal. `tune` is only meaningful on
/// radios with an internal ATU; `bandUp`/`bandDown` are FM/HT
/// staples but ambiguous on a knob-driven HF rig. Calling an
/// operation the radio doesn't support throws
/// ``RigError/unsupportedOperation(_:)`` — there is no silent
/// no-op.
public enum VFOOperation: String, Sendable, Codable, CaseIterable {
    /// Copy the active VFO's frequency and mode to the other VFO
    /// (A→B or B→A depending on which is active). Hamlib:
    /// `RIG_OP_CPY`.
    case copyVFO

    /// Swap VFO A and VFO B contents. Hamlib: `RIG_OP_XCHG`.
    /// Some radios alias `toggle` to this — operators see both
    /// names in the wild.
    case exchange

    /// Toggle the active VFO between A and B. Hamlib:
    /// `RIG_OP_TOGGLE`. Distinct from ``exchange`` only on radios
    /// that distinguish "which VFO is selected" from "what's in
    /// each VFO" (e.g. Yaesu newcat: "SV" handles both via the
    /// same wire command).
    case toggle

    /// Store the active VFO to the currently-selected memory
    /// channel ("M.W" on most front panels). Hamlib:
    /// `RIG_OP_FROM_VFO`.
    case vfoToMemory

    /// Recall the currently-selected memory channel into the
    /// active VFO ("M→V" on most front panels). Hamlib:
    /// `RIG_OP_TO_VFO`.
    case memoryToVFO

    /// Clear the currently-selected memory channel. Hamlib:
    /// `RIG_OP_MCL`.
    case memoryClear

    /// Step the active VFO up by the configured tuning step.
    /// Hamlib: `RIG_OP_UP`. Not implemented for Icom in Hamlib
    /// (use direct frequency set instead) — same here.
    case stepUp

    /// Step the active VFO down by the configured tuning step.
    /// Hamlib: `RIG_OP_DOWN`.
    case stepDown

    /// Move to the next amateur band. Hamlib: `RIG_OP_BAND_UP`.
    case bandUp

    /// Move to the previous amateur band. Hamlib:
    /// `RIG_OP_BAND_DOWN`.
    case bandDown

    /// Start automatic antenna-tuner tuning cycle. Hamlib:
    /// `RIG_OP_TUNE`. Only meaningful on radios with an
    /// internal ATU.
    case tune
}
