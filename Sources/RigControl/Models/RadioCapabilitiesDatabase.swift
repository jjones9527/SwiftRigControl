import Foundation

/// Database of detailed radio capabilities for all supported models.
///
/// Capability literals are organized by manufacturer. Each
/// vendor has a nested namespace — `RadioCapabilitiesDatabase.Icom`,
/// `RadioCapabilitiesDatabase.Yaesu`, etc. — so Xcode
/// autocomplete filters by vendor when you type the namespace
/// prefix.
///
/// ```swift
/// let caps = RadioCapabilitiesDatabase.Icom.ic7600
/// ```
///
/// This database contains accurate frequency ranges, transmit capabilities, and supported modes
/// for each radio model. Data is sourced from manufacturer specifications, operator manuals,
/// and cross-references against Hamlib's per-radio capability structs at `~/Developer/hamlib`.
///
/// All frequencies are in Hz. Frequency ranges marked with `canTransmit: false` are receive-only.
public struct RadioCapabilitiesDatabase {

    /// Icom CI-V radios.
    public enum Icom {}

    /// Yaesu transceivers.
    public enum Yaesu {}

    /// Kenwood text-protocol transceivers.
    public enum Kenwood {}

    /// Elecraft K-series.
    public enum Elecraft {}

    /// Xiegu CI-V-compatible SDR transceivers.
    public enum Xiegu {}

    /// Ten-Tec.
    public enum TenTec {}

    /// Lab599.
    public enum Lab599 {}

    /// FlexRadio Systems and compatible SDRs (PowerSDR, Thetis).
    public enum Flex {}
}
