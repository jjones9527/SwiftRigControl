import Testing
@testable import RigControl

/// Unit tests for CI-V frame construction and parsing
@Suite struct CIVFrameTests {
    // MARK: - Frame Construction Tests

    @Test func basicFrameConstruction() {
        let frame = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x1C],
            data: [0x01]
        )

        let bytes = frame.bytes()

        // Expected: FE FE A2 E0 1C 01 FD
        #expect(bytes.count == 7)
        #expect(bytes[0] == 0xFE)  // Preamble
        #expect(bytes[1] == 0xFE)  // Preamble
        #expect(bytes[2] == 0xA2)  // To
        #expect(bytes[3] == 0xE0)  // From
        #expect(bytes[4] == 0x1C)  // Command
        #expect(bytes[5] == 0x01)  // Data
        #expect(bytes[6] == 0xFD)  // Terminator
    }

    @Test func frameWithMultipleDataBytes() {
        let frame = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x05],
            data: [0x00, 0x00, 0x23, 0x14, 0x00]
        )

        let bytes = frame.bytes()

        // Expected: FE FE A2 E0 05 00 00 23 14 00 FD
        #expect(bytes.count == 11)
        #expect(bytes[0] == 0xFE)
        #expect(bytes[1] == 0xFE)
        #expect(bytes[2] == 0xA2)
        #expect(bytes[3] == 0xE0)
        #expect(bytes[4] == 0x05)
        #expect(bytes[5] == 0x00)
        #expect(bytes[6] == 0x00)
        #expect(bytes[7] == 0x23)
        #expect(bytes[8] == 0x14)
        #expect(bytes[9] == 0x00)
        #expect(bytes[10] == 0xFD)
    }

    @Test func frameWithNoData() {
        let frame = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x03]
        )

        let bytes = frame.bytes()

        // Expected: FE FE A2 E0 03 FD
        #expect(bytes.count == 6)
        #expect(bytes[0] == 0xFE)
        #expect(bytes[1] == 0xFE)
        #expect(bytes[2] == 0xA2)
        #expect(bytes[3] == 0xE0)
        #expect(bytes[4] == 0x03)
        #expect(bytes[5] == 0xFD)
    }

    // MARK: - Frame Parsing Tests

    @Test func parseBasicFrame() throws {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        let frame = try CIVFrame.parse(data)

        #expect(frame.to == 0xE0)
        #expect(frame.from == 0xA2)
        #expect(frame.command == [0xFB])
        #expect(frame.data == [])
        #expect(frame.isAck)
        #expect(!frame.isNak)
    }

    @Test func parseFrameWithData() throws {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x03, 0x00, 0x00, 0x23, 0x14, 0x00, 0xFD])
        let frame = try CIVFrame.parse(data)

        #expect(frame.to == 0xE0)
        #expect(frame.from == 0xA2)
        #expect(frame.command == [0x03])
        #expect(frame.data == [0x00, 0x00, 0x23, 0x14, 0x00])
    }

    @Test func parseNakFrame() throws {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFA, 0xFD])
        let frame = try CIVFrame.parse(data)

        #expect(frame.command == [0xFA])
        #expect(frame.isNak)
        #expect(!frame.isAck)
    }

    @Test func parseInvalidPreamble() {
        let data = Data([0xFF, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])

        #expect(throws: RigError.invalidResponse) {
            try CIVFrame.parse(data)
        }
    }

    @Test func parseInvalidTerminator() {
        let data = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFF])

        #expect(throws: RigError.invalidResponse) {
            try CIVFrame.parse(data)
        }
    }

    @Test func parseTooShort() {
        let data = Data([0xFE, 0xFE, 0xE0])

        #expect(throws: RigError.invalidResponse) {
            try CIVFrame.parse(data)
        }
    }

    // MARK: - Round-trip Tests

    @Test func roundTrip() throws {
        let original = CIVFrame(
            to: 0xA2,
            from: 0xE0,
            command: [0x05],
            data: [0x00, 0x00, 0x23, 0x14, 0x00]
        )

        let bytes = original.bytes()
        let parsed = try CIVFrame.parse(Data(bytes))

        #expect(parsed.to == original.to)
        #expect(parsed.from == original.from)
        #expect(parsed.command == original.command)
        #expect(parsed.data == original.data)
    }

    // MARK: - Command Type Tests

    @Test func pttOnFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.ptt],
            data: [0x01]
        )

        let bytes = frame.bytes()

        #expect(bytes[4] == 0x1C)  // PTT command
        #expect(bytes[5] == 0x01)  // ON
    }

    @Test func pttOffFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.ptt],
            data: [0x00]
        )

        let bytes = frame.bytes()

        #expect(bytes[4] == 0x1C)  // PTT command
        #expect(bytes[5] == 0x00)  // OFF
    }

    @Test func setFrequencyFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.setFrequency],
            data: BCDEncoding.encodeFrequency(14_230_000)
        )

        let bytes = frame.bytes()

        #expect(bytes[4] == 0x05)  // Set frequency command
        #expect(bytes[5] == 0x00)  // Frequency data starts
    }

    @Test func readFrequencyFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.readFrequency]
        )

        let bytes = frame.bytes()

        #expect(bytes[4] == 0x03)  // Read frequency command
        #expect(bytes.count == 6)  // No data
    }

    @Test func setModeFrame() {
        let frame = CIVFrame(
            to: 0xA2,
            command: [CIVFrame.Command.setMode],
            data: [CIVFrame.ModeCode.usb, 0x00]
        )

        let bytes = frame.bytes()

        #expect(bytes[4] == 0x06)  // Set mode command
        #expect(bytes[5] == 0x01)  // USB mode
        #expect(bytes[6] == 0x00)  // Default filter
    }
}
