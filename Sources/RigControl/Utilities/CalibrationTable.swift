import Foundation

/// A piecewise-linear map from a radio's raw meter reading to a
/// calibrated value, such as the S-meter in dB relative to S9.
///
/// Mirrors Hamlib's `cal_table_t` and `rig_raw2val` (`src/cal.c`):
/// readings between two points are linearly interpolated, readings
/// beyond the first or last point take that point's value. Tables are
/// copied from Hamlib's per-model `.str_cal` caps so calibrated readings
/// match what Hamlib reports for the same radio.
///
/// ```swift
/// let table = CalibrationTable([(0, -54), (130, 0), (255, 60)])
/// table.value(forRaw: 65)   // -27
/// ```
public struct CalibrationTable: Sendable, Equatable {

    /// One calibration point.
    public struct Point: Sendable, Equatable {
        /// Raw reading from the radio.
        public let raw: Int
        /// Calibrated value at that reading.
        public let value: Int

        /// Creates a point.
        ///
        /// - Parameters:
        ///   - raw: Raw reading from the radio.
        ///   - value: Calibrated value at that reading.
        public init(raw: Int, value: Int) {
            self.raw = raw
            self.value = value
        }
    }

    /// Points in ascending order of raw reading.
    public let points: [Point]

    /// Creates a table from `(raw, value)` pairs, sorted by raw reading.
    ///
    /// - Parameter pairs: The calibration points.
    public init(_ pairs: [(raw: Int, value: Int)]) {
        points = pairs.map { Point(raw: $0.raw, value: $0.value) }.sorted { $0.raw < $1.raw }
    }

    /// The calibrated value for a raw reading, rounded to the nearest
    /// integer as Hamlib's newcat backend does (`round(rig_raw2val(...))`).
    ///
    /// - Parameter raw: The raw reading.
    /// - Returns: The interpolated value, or `raw` if the table is empty.
    public func value(forRaw raw: Int) -> Int {
        guard let first = points.first, let last = points.last else { return raw }
        if raw <= first.raw { return first.value }
        if raw >= last.raw { return last.value }
        guard let upper = points.firstIndex(where: { $0.raw >= raw }), upper > 0 else {
            return first.value
        }
        let low = points[upper - 1]
        let high = points[upper]
        guard high.raw != low.raw else { return low.value }
        let fraction = Double(raw - low.raw) / Double(high.raw - low.raw)
        return Int((Double(low.value) + fraction * Double(high.value - low.value)).rounded())
    }
}
