import Testing
@testable import RigControl

/// Unit tests for BCD encoding/decoding used in Icom CI-V protocol
@Suite struct BCDEncodingTests {
    // MARK: - Frequency Encoding Tests

    @Test func encodeSimpleFrequency() {
        // 14.230 MHz = 14230000 Hz
        // BCD: 00 00 23 14 00 (little-endian)
        let result = BCDEncoding.encodeFrequency(14_230_000)

        #expect(result.count == 5)
        #expect(result[0] == 0x00)  // 00 Hz
        #expect(result[1] == 0x00)  // 00 Hz
        #expect(result[2] == 0x23)  // 23 kHz
        #expect(result[3] == 0x14)  // 14 MHz
        #expect(result[4] == 0x00)  // 000 MHz
    }

    @Test func encode7MHzFrequency() {
        // 7.100 MHz = 7100000 Hz
        // BCD: 00 00 10 07 00
        let result = BCDEncoding.encodeFrequency(7_100_000)

        #expect(result.count == 5)
        #expect(result[0] == 0x00)
        #expect(result[1] == 0x00)
        #expect(result[2] == 0x10)
        #expect(result[3] == 0x07)
        #expect(result[4] == 0x00)
    }

    @Test func encodeVHFFrequency() {
        // 146.52 MHz = 146520000 Hz (2m calling frequency)
        // BCD little-endian: 00 00 52 46 01
        let result = BCDEncoding.encodeFrequency(146_520_000)

        #expect(result.count == 5)
        #expect(result[0] == 0x00)  // 00 Hz
        #expect(result[1] == 0x00)  // 00 Hz
        #expect(result[2] == 0x52)  // 52 kHz
        #expect(result[3] == 0x46)  // 46 MHz
        #expect(result[4] == 0x01)  // 1xx MHz
    }

    @Test func encodeUHFFrequency() {
        // 446.0 MHz = 446000000 Hz (70cm)
        // BCD little-endian: 00 00 00 46 04
        let result = BCDEncoding.encodeFrequency(446_000_000)

        #expect(result.count == 5)
        #expect(result[0] == 0x00)  // 00 Hz
        #expect(result[1] == 0x00)  // 00 Hz
        #expect(result[2] == 0x00)  // 00 kHz
        #expect(result[3] == 0x46)  // 46 MHz
        #expect(result[4] == 0x04)  // 4xx MHz
    }

    // MARK: - Frequency Decoding Tests

    @Test func decodeSimpleFrequency() throws {
        let bcd: [UInt8] = [0x00, 0x00, 0x23, 0x14, 0x00]
        let result = try BCDEncoding.decodeFrequency(bcd)

        #expect(result == 14_230_000)
    }

    @Test func decode7MHzFrequency() throws {
        let bcd: [UInt8] = [0x00, 0x00, 0x10, 0x07, 0x00]
        let result = try BCDEncoding.decodeFrequency(bcd)

        #expect(result == 7_100_000)
    }

    @Test func decodeVHFFrequency() throws {
        let bcd: [UInt8] = [0x00, 0x00, 0x52, 0x46, 0x01]
        let result = try BCDEncoding.decodeFrequency(bcd)

        #expect(result == 146_520_000)
    }

    @Test func decodeInvalidLength() {
        let bcd: [UInt8] = [0x00, 0x00, 0x23]

        #expect(throws: RigError.invalidResponse) {
            try BCDEncoding.decodeFrequency(bcd)
        }
    }

    @Test func decodeInvalidBCD() {
        // 0xFF is not a valid BCD digit
        let bcd: [UInt8] = [0x00, 0x00, 0xFF, 0x14, 0x00]

        #expect(throws: RigError.invalidResponse) {
            try BCDEncoding.decodeFrequency(bcd)
        }
    }

    // MARK: - Round-trip Tests

    @Test func frequencyRoundTrip() throws {
        let frequencies: [UInt64] = [
            3_500_000,    // 80m
            7_100_000,    // 40m
            14_230_000,   // 20m SSTV
            21_300_000,   // 15m
            28_500_000,   // 10m
            146_520_000,  // 2m calling
            446_000_000,  // 70cm
        ]

        for freq in frequencies {
            let encoded = BCDEncoding.encodeFrequency(freq)
            let decoded = try BCDEncoding.decodeFrequency(encoded)
            #expect(decoded == freq, "Round-trip failed for \(freq) Hz")
        }
    }

    // MARK: - Power Level Tests

    @Test func encodePowerZero() {
        let result = BCDEncoding.encodePower(0)

        #expect(result.count == 2)
        #expect(result[0] == 0x00)
        #expect(result[1] == 0x00)
    }

    @Test func encodePowerHalf() {
        // 50% = 128
        let result = BCDEncoding.encodePower(128)

        #expect(result.count == 2)
        #expect(result[0] == 0x01)  // 1 in hundreds
        #expect(result[1] == 0x28)  // 28 in BCD (tens=2, ones=8)
    }

    @Test func encodePowerMax() {
        // 255
        let result = BCDEncoding.encodePower(255)

        #expect(result.count == 2)
        #expect(result[0] == 0x02)  // 2 in hundreds
        #expect(result[1] == 0x55)  // 55 in BCD (tens=5, ones=5)
    }

    @Test func decodePower() {
        let bcd: [UInt8] = [0x01, 0x28]
        let result = BCDEncoding.decodePower(bcd)

        #expect(result == 128)
    }

    @Test func powerRoundTrip() {
        for power in [0, 50, 100, 128, 200, 255] {
            let encoded = BCDEncoding.encodePower(power)
            let decoded = BCDEncoding.decodePower(encoded)
            #expect(decoded == power, "Round-trip failed for power \(power)")
        }
    }
}

// Make RigError equatable for testing
extension RigError: Equatable {
    public static func == (lhs: RigError, rhs: RigError) -> Bool {
        switch (lhs, rhs) {
        case (.notConnected, .notConnected),
             (.timeout, .timeout),
             (.invalidResponse, .invalidResponse),
             (.busy, .busy):
            return true
        case (.unsupportedRadio(let a), .unsupportedRadio(let b)),
             (.commandFailed(let a), .commandFailed(let b)),
             (.serialPortError(let a), .serialPortError(let b)),
             (.unsupportedOperation(let a), .unsupportedOperation(let b)),
             (.invalidParameter(let a), .invalidParameter(let b)):
            return a == b
        default:
            return false
        }
    }
}
