import Foundation

/// Represents a Variable Frequency Oscillator (VFO) on a radio transceiver.
///
/// Most amateur radio transceivers expose two independent VFOs (A and B) that
/// allow the operator to switch quickly between two frequencies or configure
/// split operation (receiving on one VFO while transmitting on the other).
/// Dual-receiver radios such as the IC-9700 additionally expose a Main and a
/// Sub receiver, each of which can operate on a different band simultaneously.
///
/// ## VFO vs. Main/Sub
///
/// - Single-receiver radios (IC-7100, IC-7600, K2, FT-891, TS-590SG, etc.) only
///   expose `.a` and `.b`.
/// - Dual-receiver radios (IC-9700, IC-7300 D-version, etc.) expose `.main` and
///   `.sub` in addition to `.a` / `.b`.  On these radios, Main and Sub are
///   independent receiver chains that can be tuned to entirely different bands.
///
/// ## Mapping to CI-V Sub-Commands
///
/// | Case    | CI-V byte (0x07 sub-cmd) |
/// |---------|--------------------------|
/// | `.a`    | 0x00                     |
/// | `.b`    | 0x01                     |
/// | `.main` | 0xD0                     |
/// | `.sub`  | 0xD1                     |
public enum VFO: String, Sendable, Codable {
    /// VFO A — the primary (main) VFO used for normal single-VFO operation.
    ///
    /// This is the default active VFO on all supported radios.  When split is
    /// enabled, VFO A is typically the receive VFO.
    case a = "A"

    /// VFO B — the secondary VFO, used for split operation or A/B comparison.
    ///
    /// When split is enabled, VFO B is typically the transmit VFO.  VFO B can
    /// also be used to preview a second frequency without disturbing VFO A.
    case b = "B"

    /// Main receiver — the primary receiver on dual-receiver radios.
    ///
    /// Used on radios with two independent receiver chains (e.g., IC-9700).
    /// The Main receiver is the one whose audio is routed to the primary speaker
    /// and whose S-meter reading appears by default.  On single-receiver radios
    /// this concept does not apply; use `.a` instead.
    case main = "Main"

    /// Sub receiver — the secondary receiver on dual-receiver radios.
    ///
    /// Used on radios with two independent receiver chains (e.g., IC-9700).
    /// The Sub receiver operates independently of Main and can be tuned to a
    /// completely different band.  On single-receiver radios this concept does
    /// not apply; use `.b` instead.
    case sub = "Sub"
}
