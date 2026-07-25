import Foundation

/// Shared helpers for Yaesu's pre-newcat 5-byte binary CAT protocols.
///
/// The FT-817 family (``YaesuPortableCAT``), FT-847 family
/// (``YaesuFT847CAT``), and FT-1000MP family (``YaesuFT1000MPCAT``)
/// all use the same fundamental frame shape:
///
/// ```text
/// [ P1, P2, P3, P4, Opcode ]
/// ```
///
/// What differs between them:
/// - **BCD endianness of the frequency payload.** FT-817 and FT-847 use
///   big-endian BCD (most-significant digit in byte 0 high nibble).
///   FT-1000MP uses little-endian BCD (least-significant digit in byte 0
///   low nibble), matching Hamlib's `to_bcd()` / `from_bcd()` helpers.
/// - **Which byte carries the mode selector.** FT-817 puts it in byte 0
///   (P1). FT-847 also byte 0. FT-1000MP puts it in byte 3 (P4), with
///   the high bit of P4 tagging VFO A vs B.
/// - **Whether the radio ACKs a set command.** FT-817 reads a 1-byte
///   ACK after every set. FT-847 and FT-1000MP are fire-and-forget.
///
/// The helpers below cover the BCD half of that split. Mode encoding
/// lives in each family's own file because it varies too much to
/// share cleanly.
enum YaesuBinaryFrame {

    /// Encodes a value into 4 bytes of 8-digit **big-endian** BCD.
    ///
    /// Each nibble is one decimal digit. Big-endian means the most
    /// significant digit lands in the high nibble of byte 0.
    ///
    /// Used by FT-817 and FT-847 families. Cross-checked against
    /// Hamlib `to_bcd_be(data, freq/10, 8)` in `rigs/yaesu/ft817.c`
    /// and `rigs/yaesu/ft847.c`.
    ///
    /// For frequency: pass `freq/10` (both families truncate to 10 Hz
    /// resolution on the wire).
    ///
    /// - Parameter value: The value to encode. Must fit in 8 decimal
    ///   digits (0-99_999_999).
    /// - Returns: 4-byte big-endian BCD representation.
    static func encodeBCDBigEndian8(_ value: UInt64) -> [UInt8] {
        var digits: [UInt8] = []
        var v = value
        for _ in 0..<8 {
            digits.append(UInt8(v % 10))
            v /= 10
        }
        // digits[0] is least-significant. Pack from most-significant
        // end back into 4 bytes, high nibble first.
        var bytes = [UInt8](repeating: 0, count: 4)
        for i in 0..<4 {
            let high = digits[7 - 2 * i]
            let low  = digits[7 - 2 * i - 1]
            bytes[i] = (high << 4) | low
        }
        return bytes
    }

    /// Decodes 4 bytes of 8-digit big-endian BCD back into an integer.
    /// Inverse of ``encodeBCDBigEndian8(_:)``.
    ///
    /// - Parameter bytes: A 4-byte slice.
    /// - Returns: The decoded integer value.
    /// - Throws: ``RigError/invalidResponse`` if any nibble is not a
    ///   valid decimal digit (0-9).
    static func decodeBCDBigEndian8(_ bytes: Data.SubSequence) throws -> UInt64 {
        guard bytes.count == 4 else {
            throw RigError.invalidResponse
        }
        var value: UInt64 = 0
        for byte in bytes {
            let high = (byte >> 4) & 0x0F
            let low  = byte & 0x0F
            guard high < 10 && low < 10 else {
                throw RigError.invalidResponse
            }
            value = value * 100 + UInt64(high) * 10 + UInt64(low)
        }
        return value
    }

    /// Encodes a value into 4 bytes of 8-digit **little-endian** BCD.
    ///
    /// Little-endian means the least-significant pair of digits lands
    /// in byte 0: byte 0 = `(digit1 << 4) | digit0`, byte 1 =
    /// `(digit3 << 4) | digit2`, etc.
    ///
    /// Used by FT-1000MP. Cross-checked against Hamlib
    /// `to_bcd(data, freq/10, 8)` in `rigs/yaesu/ft1000mp.c` line 885,
    /// which corresponds to the definition in Hamlib
    /// `src/misc.c:146`:
    ///
    /// ```c
    /// for (i = 0; i < bcd_len / 2; i++) {
    ///     unsigned char a = freq % 10;
    ///     freq /= 10;
    ///     a |= (freq % 10) << 4;
    ///     freq /= 10;
    ///     bcd_data[i] = a;
    /// }
    /// ```
    ///
    /// - Parameter value: The value to encode. Must fit in 8 decimal
    ///   digits (0-99_999_999).
    /// - Returns: 4-byte little-endian BCD representation.
    static func encodeBCDLittleEndian8(_ value: UInt64) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        var v = value
        for i in 0..<4 {
            let low = UInt8(v % 10)
            v /= 10
            let high = UInt8(v % 10)
            v /= 10
            bytes[i] = (high << 4) | low
        }
        return bytes
    }

    /// Decodes 4 bytes of 8-digit little-endian BCD. Inverse of
    /// ``encodeBCDLittleEndian8(_:)``.
    ///
    /// - Parameter bytes: A 4-byte slice.
    /// - Returns: The decoded integer value.
    /// - Throws: ``RigError/invalidResponse`` if any nibble is out of
    ///   range.
    static func decodeBCDLittleEndian8(_ bytes: Data.SubSequence) throws -> UInt64 {
        guard bytes.count == 4 else {
            throw RigError.invalidResponse
        }
        var value: UInt64 = 0
        var multiplier: UInt64 = 1
        for byte in bytes {
            let low = UInt64(byte & 0x0F)
            let high = UInt64((byte >> 4) & 0x0F)
            guard low < 10 && high < 10 else {
                throw RigError.invalidResponse
            }
            value += low * multiplier
            multiplier *= 10
            value += high * multiplier
            multiplier *= 10
        }
        return value
    }
}
