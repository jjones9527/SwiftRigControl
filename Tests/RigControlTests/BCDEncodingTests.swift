import XCTest
@testable import RigControl

final class BCDEncodingTests: XCTestCase {
    // MARK: - Frequency Encoding Tests

    func testEncodeSimpleFrequency() {
        // 14.230 MHz = 14230000 Hz
        // BCD: 00 00 23 14 00 (little-endian)
        let result = BCDEncoding.encodeFrequency(14_230_000)

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0], 0x00)  // 00 Hz
        XCTAssertEqual(result[1], 0x00)  // 00 Hz
        XCTAssertEqual(result[2], 0x23)  // 23 kHz
        XCTAssertEqual(result[3], 0x14)  // 14 MHz
        XCTAssertEqual(result[4], 0x00)  // 000 MHz
    }

    func testEncode7MHzFrequency() {
        // 7.100 MHz = 7100000 Hz
        // BCD: 00 00 10 07 00
        let result = BCDEncoding.encodeFrequency(7_100_000)

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0], 0x00)
        XCTAssertEqual(result[1], 0x00)
        XCTAssertEqual(result[2], 0x10)
        XCTAssertEqual(result[3], 0x07)
        XCTAssertEqual(result[4], 0x00)
    }

    func testEncodeVHFFrequency() {
        // 146.52 MHz = 146520000 Hz (2m calling frequency)
        // BCD: 00 00 52 65 14
        let result = BCDEncoding.encodeFrequency(146_520_000)

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0], 0x00)
        XCTAssertEqual(result[1], 0x00)
        XCTAssertEqual(result[2], 0x52)
        XCTAssertEqual(result[3], 0x65)
        XCTAssertEqual(result[4], 0x14)
    }

    func testEncodeUHFFrequency() {
        // 446.0 MHz = 446000000 Hz (70cm)
        // BCD: 00 00 00 60 44
        let result = BCDEncoding.encodeFrequency(446_000_000)

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0], 0x00)
        XCTAssertEqual(result[1], 0x00)
        XCTAssertEqual(result[2], 0x00)
        XCTAssertEqual(result[3], 0x60)
        XCTAssertEqual(result[4], 0x44)
    }

    // MARK: - Frequency Decoding Tests

    func testDecodeSimpleFrequency() throws {
        let bcd: [UInt8] = [0x00, 0x00, 0x23, 0x14, 0x00]
        let result = try BCDEncoding.decodeFrequency(bcd)

        XCTAssertEqual(result, 14_230_000)
    }

    func testDecode7MHzFrequency() throws {
        let bcd: [UInt8] = [0x00, 0x00, 0x10, 0x07, 0x00]
        let result = try BCDEncoding.decodeFrequency(bcd)

        XCTAssertEqual(result, 7_100_000)
    }

    func testDecodeVHFFrequency() throws {
        let bcd: [UInt8] = [0x00, 0x00, 0x52, 0x65, 0x14]
        let result = try BCDEncoding.decodeFrequency(bcd)

        XCTAssertEqual(result, 146_520_000)
    }

    func testDecodeInvalidLength() {
        let bcd: [UInt8] = [0x00, 0x00, 0x23]

        XCTAssertThrowsError(try BCDEncoding.decodeFrequency(bcd)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    func testDecodeInvalidBCD() {
        // 0xFF is not a valid BCD digit
        let bcd: [UInt8] = [0x00, 0x00, 0xFF, 0x14, 0x00]

        XCTAssertThrowsError(try BCDEncoding.decodeFrequency(bcd)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    // MARK: - Round-trip Tests

    func testFrequencyRoundTrip() throws {
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
            XCTAssertEqual(decoded, freq, "Round-trip failed for \(freq) Hz")
        }
    }

    // MARK: - Power Level Tests

    func testEncodePowerZero() {
        let result = BCDEncoding.encodePower(0)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], 0x00)
        XCTAssertEqual(result[1], 0x00)
    }

    func testEncodePowerHalf() {
        // 50% = 128
        let result = BCDEncoding.encodePower(128)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], 0x28)  // 28 in BCD
        XCTAssertEqual(result[1], 0x01)  // 1 in hundreds
    }

    func testEncodePowerMax() {
        // 255
        let result = BCDEncoding.encodePower(255)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], 0x55)  // 55 in BCD
        XCTAssertEqual(result[1], 0x02)  // 2 in hundreds
    }

    func testDecodePower() {
        let bcd: [UInt8] = [0x28, 0x01]
        let result = BCDEncoding.decodePower(bcd)

        XCTAssertEqual(result, 128)
    }

    func testPowerRoundTrip() {
        for power in [0, 50, 100, 128, 200, 255] {
            let encoded = BCDEncoding.encodePower(power)
            let decoded = BCDEncoding.decodePower(encoded)
            XCTAssertEqual(decoded, power, "Round-trip failed for power \(power)")
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
