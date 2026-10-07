import Foundation

/// How a Kenwood-protocol radio selects its operating mode, and in
/// particular how it reaches DATA modes.
///
/// The Kenwood text protocol has no single DATA-mode command. Hamlib
/// handles it per model, and each case here mirrors one of those
/// strategies. Radios that Hamlib gives no packet modes use
/// ``standard``, which rejects DATA modes with
/// `RigError.unsupportedOperation` instead of sending a command the
/// radio does not understand.
///
/// ```swift
/// let proto = KenwoodProtocol(
///     transport: transport,
///     capabilities: RadioCapabilitiesDatabase.Kenwood.ts590SG,
///     modeStyle: .dataSubMode
/// )
/// try await proto.setMode(.dataUSB, vfo: .a)   // MD2; then DA1;
/// ```
public enum KenwoodModeCommandStyle: Sendable, Equatable {
    /// `MD<n>;` with the shared Kenwood mode table and no DATA modes
    /// (TS-2000, TS-480, TS-870S, TS-850S, TS-570, TS-450S, TS-690S,
    /// TS-940S, TS-950S/SDX, TX-500, SDR-Console, PiHPSDR). None of
    /// these advertise `RIG_MODE_PKT*` in their Hamlib caps.
    case standard

    /// `MD<n>;` followed by `DA1;` / `DA0;` to switch the DATA
    /// sub-mode on SSB / FM / AM (TS-590S, TS-590SG). Readback adds
    /// `DA;`. Matches Hamlib `kenwood_set_mode` / `kenwood_get_mode`
    /// (`kenwood.c:2537-2556`, `2670-2727`, `2989-3020`).
    case dataSubMode

    /// `OM0<hex>;` for every mode, DATA included: `C` = LSB-D1,
    /// `D` = USB-D1, `E` = FM-D1 (TS-990S). Matches Hamlib
    /// `ts990s_mode_table` (`ts990s.c:94-120`) and the `OM` path in
    /// `kenwood.c:2631-2653`.
    case operatingMode

    /// `SF<v>;` read-modify-write: read the VFO's `SF` record, replace
    /// the mode character at offset 14, and write it back (TS-890S).
    /// DATA modes use `C` / `D` / `E` from the shared Kenwood table.
    /// Matches Hamlib `kenwood.c:2602-2630` and `2899-2912`.
    case setFrequencyAndMode

    /// `MD<n>;` where `6` is DIGL and `9` is DIGU (FlexRadio
    /// SmartSDR). Flex has no RTTY or CW-R in its CAT mode table.
    /// Matches Hamlib `flex_mode_table` (`flex6xxx.c:58-70`).
    case flexDigital

    /// `ZZMD<nn>;` two-digit extended mode command, where `07` is
    /// DIGU and `09` is DIGL (PowerSDR, Thetis). Matches Hamlib
    /// `powersdr_mode_table` and `powersdr_set_mode` /
    /// `powersdr_get_mode` (`flex6xxx.c`).
    case powerSDR
}
