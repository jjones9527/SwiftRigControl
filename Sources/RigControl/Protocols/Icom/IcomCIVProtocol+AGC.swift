import Foundation

/// AGC (Automatic Gain Control) support for Icom radios.
///
/// Icom's `0x16 0x12` AGC byte is **model-specific** — it is *not*
/// Hamlib's `RIG_AGC_*` enum (`OFF=0, FAST=2, SLOW=3, MEDIUM=5`) and
/// not the generic `D_AGC_*` defaults in `icom_defs.h`. Every radio
/// we dispatch to declares `.agc_levels_present = 1` in Hamlib with
/// its own table, and Hamlib translates through that table on both
/// set (`icom.c` `RIG_LEVEL_AGC` in `icom_set_level`) and get
/// (`icom_get_level`, rejecting unknown bytes with `-RIG_EPROTO`).
///
/// Pre-v1.2.17 this file sent the `RIG_AGC_*` enum values on the
/// wire: `.fast` → `0x02` (MID on the radio), `.medium` → `0x05`
/// (rejected), and a radio reporting FAST (`0x01`) could not be
/// read back. It also routed IC-7300 / IC-7610 / IC-7851 / IC-705
/// etc. to model-guarded helpers that threw `unsupportedOperation`.
extension IcomCIVProtocol {
    // MARK: - Unified AGC Control

    /// Sets the AGC speed for Icom radios.
    ///
    /// The speed is translated to the radio's own CI-V byte using the
    /// per-model table from Hamlib (see ``agcTable(for:)``).
    ///
    /// ```swift
    /// try await proto.setAGC(.fast)
    /// ```
    ///
    /// - Parameter speed: The desired AGC speed.
    /// - Throws: `RigError.unsupportedOperation` if this model has no
    ///   known AGC table; `RigError.invalidParameter` if the speed is
    ///   not available on this model; `RigError.commandFailed` if the
    ///   radio rejects the command.
    public func setAGC(_ speed: AGCSpeed) async throws {
        guard let table = Self.agcTable(for: radioModel) else {
            throw RigError.unsupportedOperation("AGC control not implemented for \(radioModel.rawValue)")
        }
        guard let code = table.first(where: { $0.speed == speed })?.code else {
            throw RigError.invalidParameter("\(speed.rawValue) AGC not supported on \(radioModel.rawValue)")
        }
        // setFunctionIC7600 / getFunctionIC7600 are the generic
        // 0x16 <sub> helpers despite their names — no model guard.
        try await setFunctionIC7600(CIVFrame.FunctionCode.agc, value: code)
    }

    /// Gets the current AGC speed from Icom radios.
    ///
    /// - Returns: Current AGC speed.
    /// - Throws: `RigError.unsupportedOperation` if this model has no
    ///   known AGC table; `RigError.invalidResponse` if the radio
    ///   reports a byte outside the table (Hamlib: `-RIG_EPROTO`).
    public func getAGC() async throws -> AGCSpeed {
        guard let table = Self.agcTable(for: radioModel) else {
            throw RigError.unsupportedOperation("AGC control not implemented for \(radioModel.rawValue)")
        }
        let code = try await getFunctionIC7600(CIVFrame.FunctionCode.agc)
        guard let speed = table.first(where: { $0.code == code })?.speed else {
            throw RigError.invalidResponse
        }
        return speed
    }

    // MARK: - AGC Mapping

    /// Per-model AGC translation table, mirroring each radio's
    /// `agc_levels` in its Hamlib `icom_priv_caps`.
    ///
    /// - Parameter model: The Icom (or CI-V clone) model.
    /// - Returns: `(speed, CI-V byte)` pairs, or `nil` when the model
    ///   has no table we have cross-checked.
    static func agcTable(for model: IcomRadioModel) -> [(speed: AGCSpeed, code: UInt8)]? {
        switch model {
        case .ic7600, .ic7610, .ic7100, .ic7000:
            // ic7600.c:161-167, ic7610.c:167-173, ic7100.c:199-205,
            // ic7000.c:192+ — FAST/MID/SLOW only, no OFF.
            return [(.fast, 0x01), (.medium, 0x02), (.slow, 0x03)]

        case .ic7300, .ic7300mk2, .ic9700, .ic705,
             .ic7700, .ic7760, .ic7800, .ic7851:
            // ic7300.c:454-460 (IC-7300), :563-569 (MK2), :670-676
            // (IC-9700), :726-732 (IC-705); ic7700.c:125+,
            // ic7760.c:124+, ic7800.c:137+, ic785x.c:156-162.
            // Hamlib notes that on the IC-7300 family OFF is really
            // driven by the AGC time constant, but still maps it to
            // 0x00 here — we match that for parity.
            return [(.off, 0x00), (.fast, 0x01), (.medium, 0x02), (.slow, 0x03)]

        case .ic7200:
            // ic7200.c:106+ — no MID; SLOW is 0x02.
            return [(.off, 0x00), (.fast, 0x01), (.slow, 0x02)]

        case .ic7410:
            // ic7410.c:102+ — order is reversed: SLOW=1, MID=2, FAST=3.
            return [(.off, 0x00), (.slow, 0x01), (.medium, 0x02), (.fast, 0x03)]

        case .xieguG90:
            // xiegu.c g90_priv_caps (upstream 5ac54e5b): OFF/FAST/SLOW/AUTO,
            // no MID.
            return [(.off, 0x00), (.fast, 0x01), (.slow, 0x02), (.auto, 0x03)]

        default:
            return nil
        }
    }
}
