import XCTest
@testable import RigControl

final class CIVFrameTests: XCTestCase {
    // MARK: - Frame Construction Tests

    func testBasicFrameConstruction() {
        let frame = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x1C],
            data: [0x01]
        )

        let bytes = frame.bytes()

        // Expected: FE FE A2 E0 1C 01 FD
        XCTAssertEqual(bytes.count, 7)
        XCTAssertEqual(bytes[0], 0xFE)  // Preamble
        XCTAssertEqual(bytes[1], 0xFE)  // Preamble
        XCTAssertEqual(bytes[2], 0xA2)  // To
        XCTAssertEqual(bytes[3], 0xE0)  // From
        XCTAssertEqual(bytes[4], 0x1C)  // Command
        XCTAssertEqual(bytes[5], 0x01)  // Data
        XCTAssertEqual(bytes[6], 0xFD)  // Terminator
    }

    func testFrameWithMultipleDataBytes() {
        let frame = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x05],
            data: [0x00, 0x00, 0x23, 0x14, 0x00]
        )

        let bytes = frame.bytes()

        // Expected: FE FE A2 E0 05 00 00 23 14 00 FD
        XCTAssertEqual(bytes.count, 11)
        XCTAssertEqual(bytes[0], 0xFE)
        XCTAssertEqual(bytes[1], 0xFE)
        XCTAssertEqual(bytes[2], 0xA2)
        XCTAssertEqual(bytes[3], 0xE0)
        XCTAssertEqual(bytes[4], 0x05)
        XCTAssertEqual(bytes[5], 0x00)
        XCTAssertEqual(bytes[6], 0x00)
        XCTAssertEqual(bytes[7], 0x23)
        XCTAssertEqual(bytes[8], 0x14)
        XCTAssertEqual(bytes[9], 0x00)
        XCTAssertEqual(bytes[10], 0xFD)
    }

    func testFrameWithNoData() {
        let frame = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x03]
        )

        let bytes = frame.bytes()

        // Expected: FE FE A2 E0 03 FD
        XCTAssertEqual(bytes.count, 6)
        XCTAssertEqual(bytes[0], 0xFE)
        XCTAssertEqual(bytes[1], 0xFE)
        XCTAssertEqual(bytes[2], 0xA2)
        XCTAssertEqual(bytes[3], 0xE0)
        XCTAssertEqual(bytes[4], 0x03)
        XCTAssertEqual(bytes[5], 0xFD)
    }

    // MARK: - Frame Parsing Tests

    func testParseBasicFrame() throws {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        let frame = try CIVFrame.parse(data)

        XCTAssertEqual(frame.to, 0xE0)
        XCTAssertEqual(frame.from, 0xA2)
        XCTAssertEqual(frame.command, [0xFB])
        XCTAssertEqual(frame.data, [])
        XCTAssertTrue(frame.isAck)
        XCTAssertFalse(frame.isNak)
    }

    func testParseFrameWithData() throws {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x03, 0x00, 0x00, 0x23, 0x14, 0x00, 0xFD])
        let frame = try CIVFrame.parse(data)

        XCTAssertEqual(frame.to, 0xE0)
        XCTAssertEqual(frame.from, 0xA2)
        XCTAssertEqual(frame.command, [0x03])
        XCTAssertEqual(frame.data, [0x00, 0x00, 0x23, 0x14, 0x00])
    }

    func testParseNakFrame() throws {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFA, 0xFD])
        let frame = try CIVFrame.parse(data)

        XCTAssertEqual(frame.command, [0xFA])
        XCTAssertTrue(frame.isNak)
        XCTAssertFalse(frame.isAck)
    }

    func testParseInvalidPreamble() {
        let data = Data([0xFF, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])

        XCTAssertThrowsError(try CIVFrame.parse(data)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    func testParseInvalidTerminator() {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFF])

        XCTAssertThrowsError(try CIVFrame.parse(data)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    func testParseTooShort() {
        let data = Data([0xFE, 0xFE, 0xE0])

        XCTAssertThrowsError(try CIVFrame.parse(data)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    // MARK: - Round-trip Tests

    func testRoundTrip() throws {
        let original = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x05],
            data: [0x00, 0x00, 0x23, 0x14, 0x00]
        )

        let bytes = original.bytes()
        let parsed = try CIVFrame.parse(Data(bytes))

        XCTAssertEqual(parsed.to, original.to)
        XCTAssertEqual(parsed.from, original.from)
        XCTAssertEqual(parsed.command, original.command)
        XCTAssertEqual(parsed.data, original.data)
    }

    // MARK: - Command Type Tests

    func testPTTOnFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.ptt],
            data: [0x01]
        )

        let bytes = frame.bytes()

        XCTAssertEqual(bytes[4], 0x1C)  // PTT command
        XCTAssertEqual(bytes[5], 0x01)  // ON
    }

    func testPTTOffFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.ptt],
            data: [0x00]
        )

        let bytes = frame.bytes()

        XCTAssertEqual(bytes[4], 0x1C)  // PTT command
        XCTAssertEqual(bytes[5], 0x00)  // OFF
    }

    func testSetFrequencyFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.setFrequency],
            data: BCDEncoding.encodeFrequency(14_230_000)
        )

        let bytes = frame.bytes()

        XCTAssertEqual(bytes[4], 0x05)  // Set frequency command
        XCTAssertEqual(bytes[5], 0x00)  // Frequency data starts
    }

    func testReadFrequencyFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.readFrequency]
        )

        let bytes = frame.bytes()

        XCTAssertEqual(bytes[4], 0x03)  // Read frequency command
        XCTAssertEqual(bytes.count, 6)  // No data
    }

    func testSetModeFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.setMode],
            data: [CIVFrame.ModeCode.usb, 0x00]
        )

        let bytes = frame.bytes()

        XCTAssertEqual(bytes[4], 0x06)  // Set mode command
        XCTAssertEqual(bytes[5], 0x01)  // USB mode
        XCTAssertEqual(bytes[6], 0x00)  // Default filter
    }
}
