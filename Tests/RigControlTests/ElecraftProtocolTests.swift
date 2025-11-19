import XCTest
@testable import RigControl

final class ElecraftProtocolTests: XCTestCase {
    var mockTransport: MockTransport!
    var protocol: ElecraftProtocol!

    override func setUp() async throws {
        mockTransport = MockTransport()
        protocol = ElecraftProtocol(
            transport: mockTransport,
            capabilities: .full
        )
    }

    override func tearDown() async throws {
        await protocol.disconnect()
        mockTransport = nil
        protocol = nil
    }

    // MARK: - Connection Tests

    func testConnect() async throws {
        // Mock AI0; response
        let aiCommand = "AI0;".data(using: .ascii)!
        let aiResponse = "AI0;".data(using: .ascii)!
        await mockTransport.setResponse(for: aiCommand, response: aiResponse)

        try await protocol.connect()

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "AI0;")
    }

    // MARK: - Frequency Tests

    func testSetFrequency() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Expected command: FA00014230000; (14.230 MHz)
        let expectedCommand = "FA00014230000;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FA00014230000;")
    }

    func testGetFrequency() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Query: FA;
        // Response: FA00014230000;
        let queryCommand = "FA;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let freq = try await protocol.getFrequency(vfo: .a)

        XCTAssertEqual(freq, 14_230_000)
    }

    func testSetFrequencyVFOB() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Expected command: FB00007100000; (7.100 MHz)
        let expectedCommand = "FB00007100000;".data(using: .ascii)!
        let response = "FB00007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FB00007100000;")
    }

    // MARK: - Mode Tests

    func testSetMode() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Set mode to USB (code 2)
        let expectedCommand = "MD2;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "MD2;")
    }

    func testGetMode() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Query: MD;
        // Response: MD2; (USB)
        let queryCommand = "MD;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let mode = try await protocol.getMode(vfo: .a)

        XCTAssertEqual(mode, .usb)
    }

    func testModeMappings() async throws {
        try await protocol.connect()

        let modeMappings: [(Mode, String)] = [
            (.lsb, "MD1;"),
            (.usb, "MD2;"),
            (.cw, "MD3;"),
            (.fm, "MD4;"),
            (.am, "MD5;"),
            (.dataUSB, "MD6;"),
            (.cwR, "MD7;"),
        ]

        for (mode, expectedCmd) in modeMappings {
            await mockTransport.reset()

            let expectedCommand = expectedCmd.data(using: .ascii)!
            let response = expectedCmd.data(using: .ascii)!
            await mockTransport.setResponse(for: expectedCommand, response: response)

            try await protocol.setMode(mode, vfo: .a)

            let writes = await mockTransport.recordedWrites
            XCTAssertEqual(writes.count, 1, "Mode \(mode) failed")

            let command = String(data: writes[0], encoding: .ascii)
            XCTAssertEqual(command, expectedCmd, "Mode \(mode) command mismatch")
        }
    }

    // MARK: - PTT Tests

    func testSetPTTOn() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // PTT commands may not get a response
        let expectedCommand = "TX;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await protocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "TX;")
    }

    func testSetPTTOff() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        let expectedCommand = "RX;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await protocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "RX;")
    }

    // MARK: - VFO Tests

    func testSelectVFO() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Select VFO A (FT0)
        let expectedCommand = "FT0;".data(using: .ascii)!
        let response = "FT0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol.selectVFO(.a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FT0;")
    }

    // MARK: - Power Control Tests

    func testSetPower() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Set power to 50W (50%)
        let expectedCommand = "PC050;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol.setPower(50)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "PC050;")
    }

    func testGetPower() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Query: PC;
        // Response: PC050; (50%)
        let queryCommand = "PC;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let power = try await protocol.getPower()

        // Full scale is 100W, so 50% = 50W
        XCTAssertEqual(power, 50)
    }

    // MARK: - Split Operation Tests

    func testSetSplitOn() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FT1;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol.setSplit(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FT1;")
    }

    func testGetSplit() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Query: FT;
        // Response: FT1; (split on)
        let queryCommand = "FT;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let splitEnabled = try await protocol.getSplit()

        XCTAssertTrue(splitEnabled)
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow() async throws {
        try await protocol.connect()
        await mockTransport.reset()

        // Simulate a complete workflow: Set frequency, mode, and PTT

        // 1. Set frequency
        let freqCmd = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: freqCmd, response: freqCmd)
        try await protocol.setFrequency(14_230_000, vfo: .a)

        // 2. Set mode to USB
        let modeCmd = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: modeCmd, response: modeCmd)
        try await protocol.setMode(.usb, vfo: .a)

        // 3. Enable PTT
        let pttCmd = "TX;".data(using: .ascii)!
        await mockTransport.setResponse(for: pttCmd, response: Data())
        try await protocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        XCTAssertEqual(cmd1, "FA00014230000;")
        XCTAssertEqual(cmd2, "MD2;")
        XCTAssertEqual(cmd3, "TX;")
    }
}

// Helper extension to reset MockTransport properly
extension MockTransport {
    func reset() {
        recordedWrites.removeAll()
        mockResponses.removeAll()
        shouldThrowOnWrite = false
        shouldThrowOnRead = false
    }
}
