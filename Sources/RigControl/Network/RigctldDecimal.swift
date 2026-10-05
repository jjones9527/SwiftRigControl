import Foundation

/// Canonical decimal-token parsing for the rigctld wire protocol.
///
/// Hamlib's own `netrigctl` client formats every frequency with
/// `"%"FREQFMT` where `FREQFMT` is `SCNfreq` = `"lf"`
/// (`include/hamlib/rig.h:505-514`, `rigs/dummy/netrigctl.c:1091-1095`),
/// so a stock Hamlib client sends `F 14074000.000000`, not
/// `F 14074000`. Hamlib's server-side parser accepts those tokens via
/// `rigctl_parse_double(token, RIGCTL_DECIMAL_DOT_OR_COMMA, …)`
/// (`tests/rigctl_parse.c:629`, `src/rigctl_protocol.c:25-90`), which
/// upstream tightened in `14f24827` ("enforce canonical decimal wire
/// values") to require a complete, finite token and to accept a
/// decimal comma only for scalar fields.
///
/// This type mirrors that grammar so the bridge:
/// - accepts fractional frequencies from netrigctl clients (rounded to
///   the nearest hertz, since `RigController` works in integer Hz);
/// - accepts `0,5` from clients running under a comma-decimal locale;
/// - rejects `nan`, `inf`, `0x1p3`, trailing garbage, and magnitudes that
///   would trap when later converted to `Int` (a malformed TCP client
///   must never be able to crash the host app).
enum RigctldDecimal {
    /// Largest frequency accepted, in hertz. 2^53 is the largest
    /// integer a `Double` represents exactly; anything above it is
    /// nonsense for a radio and would lose precision anyway.
    static let maxFrequencyHz: Double = 9_007_199_254_740_992

    /// Parses a scalar decimal token using Hamlib's
    /// `validate_decimal` grammar: optional sign, digits, optional
    /// `.` or `,` followed by digits (at least one digit overall), and
    /// an optional `e`/`E` exponent with at least one digit.
    ///
    /// - Parameter token: The raw whitespace-delimited token.
    /// - Returns: The finite value, or `nil` if the token is malformed
    ///   or not finite.
    static func parseDouble(_ token: String) -> Double? {
        let scalars = Array(token.unicodeScalars)
        var index = 0
        var digits = 0
        var separator: Int?

        func isDigit(_ i: Int) -> Bool {
            i < scalars.count && (48...57).contains(scalars[i].value)
        }

        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
            index += 1
        }
        while isDigit(index) { digits += 1; index += 1 }

        if index < scalars.count, scalars[index] == "." || scalars[index] == "," {
            separator = index
            index += 1
            while isDigit(index) { digits += 1; index += 1 }
        }
        guard digits > 0 else { return nil }

        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            index += 1
            if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
                index += 1
            }
            var exponentDigits = 0
            while isDigit(index) { exponentDigits += 1; index += 1 }
            guard exponentDigits > 0 else { return nil }
        }
        guard index == scalars.count else { return nil }

        var normalized = token
        if let separator, scalars[separator] == "," {
            normalized = token.replacingOccurrences(of: ",", with: ".")
        }
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    /// Parses a frequency token (integer or decimal hertz) and rounds
    /// it to the nearest hertz.
    ///
    /// - Parameter token: The raw token, e.g. `"14074000"` or
    ///   `"14074000.000000"`.
    /// - Returns: The frequency in hertz, or `nil` if the token is
    ///   malformed, negative, or out of range.
    static func parseFrequency(_ token: String) -> UInt64? {
        guard let value = parseDouble(token) else { return nil }
        let rounded = value.rounded()
        guard rounded >= 0, rounded <= maxFrequencyHz else { return nil }
        return UInt64(rounded)
    }

    /// Parses a normalized Hamlib level/power value and clamps it to
    /// `0.0...1.0` so subsequent scaling to `Int` cannot trap.
    ///
    /// - Parameter token: The raw token, e.g. `"0.5"` or `"0,5"`.
    /// - Returns: The clamped value, or `nil` if the token is malformed.
    static func parseUnitInterval(_ token: String) -> Double? {
        guard let value = parseDouble(token) else { return nil }
        return min(max(value, 0.0), 1.0)
    }
}
