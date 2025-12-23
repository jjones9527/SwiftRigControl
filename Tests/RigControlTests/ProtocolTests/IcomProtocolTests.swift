import XCTest
@testable import RigControl

final class IcomProtocolTests: XCTestCase {
    var mockTransport: MockTransport!
    var icomProtocol: IcomCIVProtocol!

    override func setUp() async throws {
        mockTransport = MockTransport()
        icomProtocol = IcomCIVProtocol(
            transport: mockTransport,
            civAddress: 0xA2,
            capabilities: .full
        )
        try await icomProtocol.connect()
    }

    override func tearDown() async throws {
        await icomProtocol.disconnect()
        mockTransport = nil
        icomProtocol = nil
    }

    // MARK: - PTT Tests

    func testSetPTTOn() async throws {
        // Expected command: FE FE A2 E0 1C 01 FD
        let expectedCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x01, 0xFD])

        // Mock ACK response: FE FE E0 A2 FB FD
        let ackResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expectedCommand, response: ackResponse)

        try await icomProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0], expectedCommand)
    }

    func testSetPTTOff() async throws {
        // Expected command: FE FE A2 E0 1C 00 FD
        let expectedCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x00, 0xFD])

        // Mock ACK response
        let ackResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expectedCommand, response: ackResponse)

        try await icomProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0], expectedCommand)
    }

    func testGetPTT() async throws {
        // Expected query: FE FE A2 E0 1C FD
        let expectedQuery = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0xFD])

        // Mock response indicating PTT is ON: FE FE E0 A2 1C 01 FD
        let response = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x1C, 0x01, 0xFD])
        await mockTransport.setResponse(for: expectedQuery, response: response)

        let result = try await icomProtocol.getPTT()

        XCTAssertTrue(result)
    }

    // MARK: - Frequency Tests

    func testSetFrequency() async throws {
        // First, mock VFO selection
        let vfoCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0x00, 0xFD])
        let vfoAck = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: vfoCommand, response: vfoAck)

        // Then, mock frequency set (14.230 MHz)
        let freqCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x05, 0x00, 0x00, 0x23, 0x14, 0x00, 0xFD])
        await mockTransport.setResponse(for: freqCommand, response: vfoAck)

        try await icomProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes[1], freqCommand)
    }

    func testGetFrequency() async throws {
        // Mock VFO selection
        let vfoCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0x00, 0xFD])
        let vfoAck = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: vfoCommand, response: vfoAck)

        // Mock frequency query
        let freqQuery = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x03, 0xFD])

        // Response with 14.230 MHz: FE FE E0 A2 03 00 00 23 14 00 FD
        let freqResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x03, 0x00, 0x00, 0x23, 0x14, 0x00, 0xFD])
        await mockTransport.setResponse(for: freqQuery, response: freqResponse)

        let result = try await icomProtocol.getFrequency(vfo: .a)

        XCTAssertEqual(result, 14_230_000)
    }

    // MARK: - Mode Tests

    func testSetMode() async throws {
        // Mock VFO selection
        let vfoCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0x00, 0xFD])
        let vfoAck = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: vfoCommand, response: vfoAck)

        // Mock mode set to USB (0x01)
        let modeCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x06, 0x01, 0x00, 0xFD])
        await mockTransport.setResponse(for: modeCommand, response: vfoAck)

        try await icomProtocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes[1], modeCommand)
    }

    func testGetMode() async throws {
        // Mock VFO selection
        let vfoCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0x00, 0xFD])
        let vfoAck = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: vfoCommand, response: vfoAck)

        // Mock mode query
        let modeQuery = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x04, 0xFD])

        // Response with USB mode: FE FE E0 A2 04 01 FD
        let modeResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x04, 0x01, 0xFD])
        await mockTransport.setResponse(for: modeQuery, response: modeResponse)

        let result = try await icomProtocol.getMode(vfo: .a)

        XCTAssertEqual(result, .usb)
    }

    // MARK: - Error Handling Tests

    func testCommandFailedOnNak() async throws {
        // Mock NAK response: FE FE E0 A2 FA FD
        let nakResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFA, 0xFD])
        let pttCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x01, 0xFD])
        await mockTransport.setResponse(for: pttCommand, response: nakResponse)

        do {
            try await icomProtocol.setPTT(true)
            XCTFail("Expected commandFailed error")
        } catch RigError.commandFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutOnRead() async throws {
        await mockTransport.reset()
        await mockTransport.setShouldThrowOnRead(true)

        do {
            try await icomProtocol.setPTT(true)
            XCTFail("Expected timeout error")
        } catch RigError.timeout {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// Helper extension for MockTransport testing
extension MockTransport {
    func setProperty<T>(_ keyPath: ReferenceWritableKeyPath<MockTransport, T>, to value: T) {
        self[keyPath: keyPath] = value
    }
}
