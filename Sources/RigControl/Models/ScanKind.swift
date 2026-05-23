import Foundation

/// What kind of scan to start on the radio.
///
/// Modeled directly on Hamlib's `RIG_SCAN_*` bitfield from
/// `include/hamlib/rig.h`. Per-radio support varies — check
/// the matching `RigCapabilities.supports*Scan` flag before
/// calling ``SupportsScanning/startScan(_:)``, or trap
/// ``RigError/unsupportedOperation(_:)``.
///
/// ## Per-verified-radio support
///
/// | Kind                       | IC-7100 | IC-7600 | IC-9700 |
/// | -------------------------- | ------- | ------- | ------- |
/// | ``vfo``                    | ✓       | ✓       | ✗       |
/// | ``memory``                 | ✓       | ✓       | ✓       |
/// | ``selectedMemory``         | ✓       | ✗       | ✓       |
/// | ``priority``               | ✓       | ✓       | ✗       |
/// | ``programmed``             | ✗       | ✓       | ✓       |
/// | ``deltaF``                 | ✗       | ✓       | ✗       |
public enum ScanKind: String, Sendable, Equatable, CaseIterable {
    /// Tune across the current VFO's full range, stopping on
    /// signals that break squelch. Hamlib `RIG_SCAN_VFO`.
    case vfo

    /// Scan all memory channels in sequence. Hamlib `RIG_SCAN_MEM`.
    case memory

    /// Scan only memory channels marked as "selected" (the radio's
    /// internal flag). Hamlib `RIG_SCAN_SLCT`.
    case selectedMemory

    /// Priority watch — periodically sample a designated priority
    /// channel while operating on another frequency. Hamlib
    /// `RIG_SCAN_PRIO`.
    case priority

    /// Programmed scan between two edge frequencies stored on the
    /// radio (set via the radio's front panel or memory channels
    /// designated as "scan edge"). Hamlib `RIG_SCAN_PROG`.
    case programmed

    /// Delta-frequency scan: a narrow scan window around the
    /// current frequency. Hamlib `RIG_SCAN_DELTA`.
    case deltaF
}
