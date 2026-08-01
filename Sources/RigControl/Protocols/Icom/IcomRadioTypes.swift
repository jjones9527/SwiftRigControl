import Foundation

/// Types and enums for Icom radio behavior classification.
///
/// These types help categorize Icom radios by their VFO operation models,
/// command requirements, and other behavioral characteristics.

// MARK: - VFO Operation Model

/// Describes how a radio handles VFO operations.
///
/// Different Icom radios have different approaches to VFO (Variable Frequency Oscillator) management:
/// - Some can target specific VFOs directly in each command
/// - Some operate only on the "current" VFO and require switching first
/// - Dual-receiver radios use Main/Sub band architecture instead of VFO A/B
/// - Some radios (receivers) don't support VFO operations at all
public enum VFOOperationModel: Sendable {
    /// Radio can target VFO A or VFO B directly in commands and supports
    /// the `0x26` targetable-mode opcode for DATA-mode set.
    ///
    /// Wire behavior:
    /// - `selectVFOCommand` emits `0x07 [0x00]` (VFO A) / `0x07 [0x01]`
    ///   (VFO B).
    /// - `setDataModeCommand` emits the newer `0x26` opcode with a 3-byte
    ///   payload carrying the DATA flag inline (no separate `0x1A 0x06`
    ///   follow-up).
    ///
    /// Shipped as of v1.2.6 for: IC-7300, IC-7700, IC-R8600, IC-R75,
    /// IC-R9500, IC-R20, IC-92AD, IC-F8101, ID-1. Also used by the
    /// dedicated `IC706CommandSet` and `IC746CommandSet` types.
    ///
    /// Note: some entries in that list (IC-R8600, IC-R75, IC-R9500,
    /// IC-R20, IC-92AD, ID-1) do not have `RIG_TARGETABLE_MODE` in their
    /// Hamlib backend, meaning their firmware may not accept the `0x26`
    /// DATA-mode opcode. These are receivers or legacy handhelds where
    /// TX / DATA modes are rarely exercised; see
    /// `Documentation/VFO_MODEL_AUDIT.md`.
    ///
    /// **v1.2.6 change:** IC-7000 previously shipped as `.targetable`;
    /// audit surfaced that Hamlib treats it as non-targetable (and
    /// forbids the mode filter byte and DATA-mode dispatch), so it was
    /// re-classified as `.currentOnly` with `requiresModeFilter: false`
    /// and `supportsDataMode: false`.
    case targetable

    /// Radio operates only on the "current" VFO — must explicitly switch
    /// the active VFO before operations.
    ///
    /// Wire behavior:
    /// - `selectVFOCommand` emits `0x07 [0x00]` (VFO A) / `0x07 [0x01]`
    ///   (VFO B) — same bytes as `.targetable`, but the caller sequences
    ///   `select` before `set` for every operation.
    /// - `setDataModeCommand` emits the legacy 2-frame form: `0x06`
    ///   base mode + `0x1A 0x06` sub-command to flip the DATA bit.
    ///
    /// Shipped as of v1.2.6 for: IC-7000, IC-7200, IC-718, IC-703,
    /// IC-7410, ID-31, IC-R6, IC-R7100, IC-RX7. Also used by the
    /// dedicated `IC7100CommandSet` (which drives IC-7100 and IC-705).
    case currentOnly

    /// Radio uses Main/Sub receiver architecture. Main / Sub receivers can
    /// be tuned to different bands simultaneously. Does not use the
    /// `0x26` opcode.
    ///
    /// Wire behavior:
    /// - `selectVFOCommand` emits `0x07 [0xD0]` (Main) / `0x07 [0xD1]`
    ///   (Sub). Callers passing `.a` / `.b` for API compatibility get
    ///   `.a` → Main and `.b` → Sub as a fallback.
    /// - `setDataModeCommand` emits the legacy 2-frame form (`0x06` +
    ///   `0x1A 0x06`).
    ///
    /// Shipped as of v1.2.5 for: IC-7600, IC-7610, IC-7800, IC-7851,
    /// IC-9100, IC-910H, IC-2730, ID-5100, ID-4100, IC-R30, ID-51, ID-52.
    /// Also used by the dedicated `IC756CommandSet`.
    ///
    /// Hamlib flags IC-7600 / IC-7610 / IC-7800 / IC-7851 as
    /// `RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE` — potentially eligible
    /// for `.targetable`. The `.mainSub` choice is under audit (see
    /// `Documentation/VFO_MODEL_AUDIT.md`).
    case mainSub

    /// Radio uses Main/Sub receiver architecture with VFO A/B per receiver
    /// (4-state model). Satellite-mode capable.
    ///
    /// Wire behavior:
    /// - `selectVFOCommand` accepts both `.main` / `.sub` (emitting
    ///   `0xD0` / `0xD1`) and `.a` / `.b` (emitting `0x00` / `0x01` on
    ///   the currently-selected receiver).
    /// - `setDataModeCommand` emits the legacy 2-frame form.
    /// - Total of 4 VFO states: Main-A, Main-B, Sub-A, Sub-B.
    /// - Required for satellite-mode operation (independent VFO tracking
    ///   per receiver).
    ///
    /// Used as of v1.2.5 exclusively by the dedicated `IC9700CommandSet`
    /// (IC-9700). No `StandardIcomCommandSet` variant currently ships
    /// with this model — IC-9100, which has a matching architecture, is
    /// shipped as plain `.mainSub`. See
    /// `Documentation/VFO_MODEL_AUDIT.md` for the deferred question.
    case mainSubDualVFO

    /// Radio does not support VFO operations. VFO selection commands
    /// return `nil`.
    ///
    /// Used as of v1.2.5 by no `StandardIcomCommandSet` variant.
    /// Reserved for scanners and single-VFO receivers where dispatch
    /// should skip VFO selection entirely.
    ///
    /// Note: several `StandardIcomCommandSet` receiver variants
    /// (IC-R8600, IC-R75, IC-R9500, IC-R20) currently ship as
    /// `.targetable` even though they lack functional VFO A/B addressing
    /// — those may migrate to `.none` when the VFO audit is resolved.
    case none
}

// Note: CI-V Frame constants (Command, VFOSelect, ModeCode, LevelRead) are defined in CIVFrame.swift

// MARK: - VFO Code Helpers

/// Helper functions for converting VFO enums to CI-V codes
public enum VFOCodeHelper {
    /// Get standard VFO code for targetable or currentOnly radios
    /// - Parameter vfo: The VFO to convert
    /// - Returns: VFO code (0x00 for A/Main, 0x01 for B/Sub)
    public static func standardCode(for vfo: VFO) -> UInt8 {
        switch vfo {
        case .a, .main:
            return CIVFrame.VFOSelect.vfoA
        case .b, .sub:
            return CIVFrame.VFOSelect.vfoB
        }
    }

    /// Get Main/Sub band selection code for dual-receiver radios (2-state model)
    /// - Parameter vfo: The VFO to convert (.main or .sub)
    /// - Returns: Band selection code if valid, nil if VFO A/B used
    public static func mainSubCode(for vfo: VFO) -> UInt8? {
        switch vfo {
        case .main:
            return CIVFrame.VFOSelect.main  // 0xD0
        case .sub:
            return CIVFrame.VFOSelect.sub   // 0xD1
        case .a, .b:
            // 2-state Main/Sub radios (IC-7600) don't support VFO A/B codes
            return nil
        }
    }

    /// Get VFO A/B selection code for dual-VFO radios (4-state model)
    /// - Parameter vfo: The VFO to convert (.a or .b)
    /// - Returns: VFO selection code if valid, nil if Main/Sub used
    /// - Note: Used by IC-9700, IC-9100 to select VFO A/B on current receiver
    public static func dualVFOCode(for vfo: VFO) -> UInt8? {
        switch vfo {
        case .a:
            return CIVFrame.VFOSelect.vfoA  // 0x00
        case .b:
            return CIVFrame.VFOSelect.vfoB  // 0x01
        case .main, .sub:
            // VFO A/B codes don't apply to band selection
            return nil
        }
    }
}
