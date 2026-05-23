import Foundation

/// A single reading from one of the radio's transmit-side meters.
///
/// `MeterReading` is the value returned by the
/// ``CATProtocol/getRFPowerOut()``, ``CATProtocol/getSWR()``,
/// ``CATProtocol/getALC()``, ``CATProtocol/getComp()``,
/// ``CATProtocol/getVoltage()``, and ``CATProtocol/getCurrent()``
/// methods, and by the matching ``RigController`` accessors.
///
/// ## Reading interpretation
///
/// The raw 0–255 value the radio puts on the wire is exposed
/// through ``raw``. The library applies the standard piecewise-
/// linear calibration curve Hamlib uses for the same meter (see
/// `~/Developer/hamlib/rigs/icom/icom.c` `icom_default_*_cal`)
/// and exposes:
///
/// - ``normalized`` — a 0.0…1.0+ fractional reading suitable for
///   driving a progress bar without further math. For SWR this is
///   `(swrRatio - 1.0) / 9.0` clamped to 1.0 (so a UI bar fills
///   somewhere between 1:1 SWR and ~10:1 SWR).
/// - A per-kind scaled accessor (``watts``, ``swrRatio``,
///   ``volts``, ``amps``, ``dB``) that returns the meter in its
///   natural physical unit. For meters that don't have one of these
///   (e.g., ALC is a relative reading), only ``normalized`` is
///   meaningful.
///
/// ## Hamlib parity
///
/// Hamlib exposes these as `float` levels (`RIG_LEVEL_SWR`,
/// `RIG_LEVEL_RFPOWER_METER`, `RIG_LEVEL_RFPOWER_METER_WATTS`,
/// `RIG_LEVEL_COMP_METER`, `RIG_LEVEL_VD_METER`,
/// `RIG_LEVEL_ID_METER`, `RIG_LEVEL_ALC`). The Swift facade keeps
/// the same numeric semantics and adds the typed accessors.
public struct MeterReading: Sendable, Equatable {

    /// Which meter this reading is from.
    public let kind: Kind

    /// The raw byte value the radio sent (0…255).
    public let raw: Int

    /// Normalized 0.0…1.0+ representation, suitable for a progress
    /// bar with no further math. See per-meter notes:
    ///
    /// - `.rfPower`: `0.0` = 0 W, `1.0` = the radio's calibrated max
    ///   output (≈ 120 W on the default Icom curve).
    /// - `.swr`: `0.0` = 1:1 (perfect match), `1.0` = ~10:1 or
    ///   worse. The actual SWR ratio is on ``swrRatio``.
    /// - `.alc`: `0.0` = no ALC action, `1.0` = full ALC limiting.
    /// - `.comp`: `0.0` = no compression, `1.0` = ~30 dB compression.
    /// - `.voltage`: `0.0` = 0 V, `1.0` = ≈16 V (Icom default).
    /// - `.current`: `0.0` = 0 A, `1.0` = ≈25 A (Icom default).
    public let normalized: Double

    /// Which transmit-side meter a reading is from. Discriminates
    /// the typed-accessor branch on ``MeterReading``.
    public enum Kind: String, Sendable, Equatable, CaseIterable {
        /// RF power output. Use ``MeterReading/watts`` for watts.
        case rfPower
        /// SWR. Use ``MeterReading/swrRatio`` for the X:1 ratio.
        case swr
        /// ALC (Automatic Level Control). Only ``normalized`` is meaningful.
        case alc
        /// Speech compressor activity. Use ``MeterReading/dB``.
        case comp
        /// Drain / supply voltage. Use ``MeterReading/volts``.
        case voltage
        /// Drain / collector current. Use ``MeterReading/amps``.
        case current
    }

    /// Constructs a reading from its three components. Use the
    /// convenience ``decode(kind:raw:)`` factory in most cases;
    /// this initializer is exposed for tests and for protocols
    /// that build readings outside the standard Icom curve.
    public init(kind: Kind, raw: Int, normalized: Double) {
        self.kind = kind
        self.raw = raw
        self.normalized = normalized
    }

    /// RF power output in watts, if this is an `.rfPower` reading.
    /// Returns `nil` for any other meter kind.
    ///
    /// Uses the Icom default RF-power meter calibration curve.
    public var watts: Double? {
        kind == .rfPower ? Self.rfPowerCurve.interpolate(rawDouble) : nil
    }

    /// SWR as an X:1 ratio, if this is a `.swr` reading. Returns
    /// `nil` for any other meter kind. The curve maps `raw == 0` to
    /// 1.0 (perfect match) and `raw == 240` to 6.0 (i.e. 6:1).
    public var swrRatio: Double? {
        kind == .swr ? Self.swrCurve.interpolate(rawDouble) : nil
    }

    /// Speech compressor activity in dB, if this is a `.comp`
    /// reading. Returns `nil` otherwise.
    public var dB: Double? {
        kind == .comp ? Self.compCurve.interpolate(rawDouble) : nil
    }

    /// Drain / supply voltage in volts, if this is a `.voltage`
    /// reading. Returns `nil` otherwise.
    public var volts: Double? {
        kind == .voltage ? Self.voltageCurve.interpolate(rawDouble) : nil
    }

    /// Drain / collector current in amperes, if this is a
    /// `.current` reading. Returns `nil` otherwise.
    public var amps: Double? {
        kind == .current ? Self.currentCurve.interpolate(rawDouble) : nil
    }

    /// Human-readable description, e.g. "50.0 W", "1.5:1", "12.4 V",
    /// "ALC 75%". For meters with a natural unit, the unit is used;
    /// for ALC and meters lacking a unit, the normalized value is
    /// rendered as a percentage.
    public var description: String {
        switch kind {
        case .rfPower:
            return String(format: "%.1f W", watts ?? 0)
        case .swr:
            return String(format: "%.1f:1", swrRatio ?? 1)
        case .alc:
            return String(format: "ALC %.0f%%", normalized * 100)
        case .comp:
            return String(format: "%.1f dB", dB ?? 0)
        case .voltage:
            return String(format: "%.1f V", volts ?? 0)
        case .current:
            return String(format: "%.1f A", amps ?? 0)
        }
    }

    private var rawDouble: Double { Double(raw) }
}

extension MeterReading: CustomStringConvertible {}

// MARK: - Calibration curves
//
// All values transcribed from Hamlib's icom_default_*_cal tables in
// rigs/icom/icom.c. Per-radio overrides can replace these via a
// future RigCapabilities meter_cal field; for now the defaults match
// what Hamlib applies to every Icom radio that doesn't supply its
// own override (which is most of them).

extension MeterReading {

    /// Piecewise-linear calibration table mapping raw 0..255 byte
    /// values to a physical-unit value.
    internal struct CalibrationCurve: Sendable {
        let points: [(raw: Double, value: Double)]

        func interpolate(_ raw: Double) -> Double {
            guard let first = points.first else { return 0 }
            if raw <= first.raw { return first.value }
            guard let last = points.last else { return first.value }
            if raw >= last.raw { return last.value }

            // Find the bracketing segment. Tables are tiny (≤13
            // points) so a linear walk is fine — and clearer than a
            // binary search for this data size.
            for i in 1..<points.count {
                let a = points[i - 1]
                let b = points[i]
                if raw <= b.raw {
                    let span = b.raw - a.raw
                    if span <= 0 { return b.value }
                    let t = (raw - a.raw) / span
                    return a.value + t * (b.value - a.value)
                }
            }
            return last.value
        }
    }

    // RF power: raw → watts. From icom_default_rfpower_meter_cal.
    internal static let rfPowerCurve = CalibrationCurve(points: [
        (0, 0), (21, 5), (43, 10), (65, 15), (83, 20), (95, 25),
        (105, 30), (114, 35), (124, 40), (143, 50), (183, 75),
        (213, 100), (255, 120),
    ])

    // SWR: raw → ratio. From icom_default_swr_cal.
    internal static let swrCurve = CalibrationCurve(points: [
        (0, 1.0), (48, 1.5), (80, 2.0), (120, 3.0), (240, 6.0),
    ])

    // COMP: raw → dB. From icom_default_comp_meter_cal.
    internal static let compCurve = CalibrationCurve(points: [
        (0, 0), (130, 15), (241, 30),
    ])

    // Voltage: raw → volts. From icom_default_vd_meter_cal.
    internal static let voltageCurve = CalibrationCurve(points: [
        (0, 0), (13, 10), (241, 16),
    ])

    // Current: raw → amps. From icom_default_id_meter_cal.
    internal static let currentCurve = CalibrationCurve(points: [
        (0, 0), (97, 10), (146, 15), (241, 25),
    ])
}

// MARK: - Convenience normalisations
//
// For `MeterReading.normalized` we want a single 0..1+ number per
// kind that drives a progress bar reasonably. Encoder rules:
//
//   .rfPower : raw / 213 → max becomes ~1.0 at 100 W (typical max),
//              clipped to 1.0 above that.
//   .swr     : (raw / 240) → 0..1, but mapped through swrCurve to
//              normalize against ~10:1 worst case.
//   .alc     : raw / 120 (the Hamlib ALC curve hits 1.0 at raw=120).
//   .comp    : raw / 241 (raw is the curve's natural extent).
//   .voltage : raw / 241.
//   .current : raw / 241.

extension MeterReading {

    /// Builds a `MeterReading` from the raw byte the radio sent,
    /// computing ``normalized`` with the per-kind rule documented on
    /// that property.
    public static func decode(kind: Kind, raw: Int) -> MeterReading {
        let r = Double(raw)
        let n: Double
        switch kind {
        case .rfPower:
            // Hamlib's RFPOWER_METER returns fraction-of-100W: raw/213
            // hits 1.0 at the "100 W" calibration point, then keeps
            // growing for radios that exceed 100 W output.
            n = r / 213.0
        case .swr:
            // Map to 0..1 across the curve: (ratio - 1) / 9, clamped.
            let ratio = swrCurve.interpolate(r)
            n = min(max((ratio - 1.0) / 9.0, 0.0), 1.0)
        case .alc:
            // ALC saturates at raw=120 in Hamlib's curve.
            n = min(r / 120.0, 1.0)
        case .comp, .voltage, .current:
            n = r / 241.0
        }
        return MeterReading(kind: kind, raw: raw, normalized: n)
    }
}
