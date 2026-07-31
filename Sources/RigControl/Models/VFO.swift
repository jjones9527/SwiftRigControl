import Foundation

/// Represents a Variable Frequency Oscillator (VFO) on a radio transceiver.
///
/// Most amateur radio transceivers expose two independent VFOs (A and B) that
/// allow the operator to switch quickly between two frequencies or configure
/// split operation (receiving on one VFO while transmitting on the other).
/// Dual-receiver radios such as the IC-9700 additionally expose a Main and a
/// Sub receiver, each of which can operate on a different band simultaneously.
///
/// ## VFO vs. Main/Sub — the honest picture
///
/// The `.a` / `.b` / `.main` / `.sub` cases are a **caller-facing** vocabulary.
/// Each radio maps them to a specific wire opcode via its `VFOOperationModel`
/// (see ``VFOOperationModel``). The mapping is not always what the case name
/// suggests:
///
/// - **`.targetable` / `.currentOnly` radios** (IC-7300, IC-7100, IC-705, K2,
///   FT-891, TS-590SG, most Yaesu/Kenwood/Elecraft HF) — `.a` and `.b` map
///   directly to the classic VFO A/B `0x00` / `0x01` codes. The `.main` /
///   `.sub` cases are not used on these radios.
/// - **`.mainSub` radios** (see the list under ``VFOOperationModel/mainSub``)
///   — `.main` / `.sub` map to the Main/Sub receiver `0xD0` / `0xD1` codes.
///   `.a` and `.b` are silently mapped to Main / Sub respectively as a
///   compatibility fallback so that generic split-mode callers (WSJT-X style)
///   still get a valid selection. On these radios, `.a` addresses the Main
///   receiver — not "VFO A on the currently selected receiver."
/// - **`.mainSubDualVFO` radios** (IC-9700 today) — every case is meaningful:
///   `.main` / `.sub` select the receiver, `.a` / `.b` select the VFO within
///   the currently-selected receiver.
///
/// The `.mainSub` fallback semantics on radios like IC-7600 / IC-7610 / etc.
/// is an area of open architecture review — Hamlib flags several of these
/// radios as targetable-capable (`RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE`),
/// which would give proper VFO A/B addressing within a receiver, but the
/// shipped catalog treats them as pure Main/Sub. See
/// `Documentation/VFO_MODEL_AUDIT.md` for the audit table and the deferred
/// decision.
///
/// ## Mapping to CI-V Sub-Commands
///
/// The bytes on the wire depend on the radio's `VFOOperationModel`. For an
/// unqualified quick reference:
///
/// | Case    | CI-V byte (0x07 sub-cmd) — targetable/currentOnly | mainSub |
/// |---------|---------------------------------------------------|---------|
/// | `.a`    | 0x00                                              | 0xD0 (falls back to Main) |
/// | `.b`    | 0x01                                              | 0xD1 (falls back to Sub) |
/// | `.main` | (unused)                                          | 0xD0 |
/// | `.sub`  | (unused)                                          | 0xD1 |
public enum VFO: String, Sendable, Codable {
    /// VFO A — the primary VFO on classic VFO A/B radios.
    ///
    /// On `.targetable` and `.currentOnly` radios this emits the standard
    /// VFO A code `0x00`. When split is enabled, VFO A is typically the
    /// receive VFO.
    ///
    /// On `.mainSub` radios this **silently maps to the Main receiver
    /// (`0xD0`)** as a caller-compatibility fallback. Callers who need
    /// explicit receiver targeting on those radios should use `.main` /
    /// `.sub` directly. See `Documentation/VFO_MODEL_AUDIT.md` for the
    /// audit context.
    case a = "A"

    /// VFO B — the secondary VFO on classic VFO A/B radios.
    ///
    /// On `.targetable` and `.currentOnly` radios this emits the standard
    /// VFO B code `0x01`. When split is enabled, VFO B is typically the
    /// transmit VFO.
    ///
    /// On `.mainSub` radios this **silently maps to the Sub receiver
    /// (`0xD1`)** as a caller-compatibility fallback. See `.a` for the
    /// full note.
    case b = "B"

    /// Main receiver — the primary receiver on dual-receiver radios.
    ///
    /// Used explicitly on `.mainSub` and `.mainSubDualVFO` radios (IC-9700,
    /// IC-7600, IC-7610, IC-9100, etc. — see ``VFOOperationModel/mainSub``
    /// for the full list). The Main receiver is the one whose audio is
    /// routed to the primary speaker and whose S-meter reading appears
    /// by default.
    ///
    /// On single-receiver `.targetable` or `.currentOnly` radios this
    /// case is not routed to any wire byte; use `.a` instead.
    case main = "Main"

    /// Sub receiver — the secondary receiver on dual-receiver radios.
    ///
    /// Used explicitly on `.mainSub` and `.mainSubDualVFO` radios. The Sub
    /// receiver operates independently of Main and can be tuned to a
    /// completely different band. On single-receiver radios this case
    /// is not routed to any wire byte; use `.b` instead.
    case sub = "Sub"
}
