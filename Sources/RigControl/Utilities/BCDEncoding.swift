import Foundation

/// Utilities for Binary Coded Decimal (BCD) encoding used by Icom radios.
///
/// BCD encoding represents each decimal digit as a 4-bit binary value.
/// For example, the number 123 would be encoded as 0x01 0x23.
public enum BCDEncoding {
    /// Encodes a frequency in Hz to BCD format used by Icom radios.
    ///
    /// Icom radios use 5-byte little-endian BCD encoding for frequencies.
    /// For example, 14.230 MHz (14230000 Hz) encodes as: 00 00 23 14 00
    ///
    /// - Parameter hz: Frequency in Hertz
    /// - Returns: 5-byte BCD encoded frequency
    public static func encodeFrequency(_ hz: UInt64) -> [UInt8] {
        var freq = hz
        var result = [UInt8](repeating: 0, count: 5)

        for i in 0..<5 {
            let low = UInt8(freq % 10)
            freq /= 10
            let high = UInt8(freq % 10)
            freq /= 10

            result[i] = (high << 4) | low
        }

        return result
    }

    /// Decodes a BCD-encoded frequency to Hz.
    ///
    /// - Parameter bcd: 5-byte BCD encoded frequency
    /// - Returns: Frequency in Hertz
    /// - Throws: `RigError.invalidResponse` if BCD data is invalid
    public static func decodeFrequency(_ bcd: [UInt8]) throws -> UInt64 {
        guard bcd.count == 5 else {
            throw RigError.invalidResponse
        }

        var hz: UInt64 = 0
        var multiplier: UInt64 = 1

        for byte in bcd {
            let low = byte & 0x0F
            let high = (byte >> 4) & 0x0F

            guard low <= 9 && high <= 9 else {
                throw RigError.invalidResponse
            }

            hz += UInt64(low) * multiplier
            multiplier *= 10
            hz += UInt64(high) * multiplier
            multiplier *= 10
        }

        return hz
    }

    /// Encodes a power level (0-255) to BCD format.
    ///
    /// IC-7100/IC-705 use big-endian BCD for power (0x14 0x0A command):
    /// - Byte 0: hundreds digit in lower nibble (upper nibble unused/zero)
    /// - Byte 1: tens digit in upper nibble, ones digit in lower nibble
    /// Example: 255 -> [0x02, 0x55] (not [0x55, 0x02])
    ///
    /// - Parameter level: Power level (0-255)
    /// - Returns: 2-byte BCD encoded power level
    public static func encodePower(_ level: Int) -> [UInt8] {
        let clamped = min(max(level, 0), 255)
        let ones = UInt8(clamped % 10)
        let tens = UInt8((clamped / 10) % 10)
        let hundreds = UInt8(clamped / 100)

        return [
            hundreds,              // Byte 0: hundreds in lower nibble
            (tens << 4) | ones     // Byte 1: tens in upper nibble, ones in lower nibble
        ]
    }

    /// Decodes a BCD-encoded power level.
    ///
    /// IC-7100/IC-705 use big-endian BCD for power (0x14 0x0A command):
    /// - Byte 0: hundreds digit in lower nibble (upper nibble unused/zero)
    /// - Byte 1: tens digit in upper nibble, ones digit in lower nibble
    /// Example: [0x02, 0x55] -> 255 (not 502)
    ///
    /// - Parameter bcd: 2-byte BCD encoded power level
    /// - Returns: Power level (0-255)
    public static func decodePower(_ bcd: [UInt8]) -> Int {
        guard bcd.count >= 2 else { return 0 }

        let hundreds = Int(bcd[0] & 0x0F)   // Byte 0: hundreds in lower nibble
        let tens = Int((bcd[1] >> 4) & 0x0F)  // Byte 1: tens in upper nibble
        let ones = Int(bcd[1] & 0x0F)       // Byte 1: ones in lower nibble

        return hundreds * 100 + tens * 10 + ones
    }
}
