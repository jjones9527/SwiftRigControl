import XCTest
@testable import RigControl

final class KenwoodProtocolTests: XCTestCase {
    var mockTransport: MockTransport!
    var kenwoodProtocol: KenwoodProtocol!

    override func setUp() async throws {
        mockTransport = MockTransport()
        kenwoodProtocol = KenwoodProtocol(
            transport: mockTransport,
            capabilities: .full
        )
    }

    override func tearDown() async throws {
        await kenwoodProtocol.disconnect()
        mockTransport = nil
        kenwoodProtocol = nil
    }

    // MARK: - Connection Tests

    func testConnect() async throws {
        // Mock AI0; response (auto-info disable)
        let aiCommand = "AI0;".data(using: .ascii)!
        let aiResponse = "AI0;".data(using: .ascii)!
        await mockTransport.setResponse(for: aiCommand, response: aiResponse)

        try await kenwoodProtocol.connect()

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "AI0;")
    }

    // MARK: - Frequency Tests

    func testSetFrequency() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Expected command: FA00014230000; (14.230 MHz)
        let expectedCommand = "FA00014230000;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FA00014230000;")
    }

    func testGetFrequency() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Query: FA;
        // Response: FA00014230000;
        let queryCommand = "FA;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let freq = try await kenwoodProtocol.getFrequency(vfo: .a)

        XCTAssertEqual(freq, 14_230_000)
    }

    func testSetFrequencyVFOB() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Expected command: FB00007100000; (7.100 MHz)
        let expectedCommand = "FB00007100000;".data(using: .ascii)!
        let response = "FB00007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FB00007100000;")
    }

    // MARK: - Mode Tests

    func testSetMode() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Set mode to USB (code 2)
        let expectedCommand = "MD2;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "MD2;")
    }

    func testGetMode() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Query: MD;
        // Response: MD2; (USB)
        let queryCommand = "MD;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let mode = try await kenwoodProtocol.getMode(vfo: .a)

        XCTAssertEqual(mode, .usb)
    }

    func testModeMappings() async throws {
        try await kenwoodProtocol.connect()

        let modeMappings: [(Mode, String)] = [
            (.lsb, "MD1;"),
            (.usb, "MD2;"),
            (.cw, "MD3;"),
            (.fm, "MD4;"),
            (.am, "MD5;"),
            (.rtty, "MD6;"),
            (.cwR, "MD7;"),
            (.dataLSB, "MD9;"),  // Kenwood uses 9 for data mode
        ]

        for (mode, expectedCmd) in modeMappings {
            await mockTransport.reset()

            let expectedCommand = expectedCmd.data(using: .ascii)!
            let response = expectedCmd.data(using: .ascii)!
            await mockTransport.setResponse(for: expectedCommand, response: response)

            try await kenwoodProtocol.setMode(mode, vfo: .a)

            let writes = await mockTransport.recordedWrites
            XCTAssertEqual(writes.count, 1, "Mode \(mode) failed")

            let command = String(data: writes[0], encoding: .ascii)
            XCTAssertEqual(command, expectedCmd, "Mode \(mode) command mismatch")
        }
    }

    // MARK: - PTT Tests

    func testSetPTTOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood uses TX1 for PTT on
        let expectedCommand = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await kenwoodProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "TX1;")
    }

    func testSetPTTOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood uses TX0 for PTT off
        let expectedCommand = "TX0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await kenwoodProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "TX0;")
    }

    func testGetPTT() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Query: TX;
        // Response: TX1; (PTT on)
        let queryCommand = "TX;".data(using: .ascii)!
        let response = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let enabled = try await kenwoodProtocol.getPTT()

        XCTAssertTrue(enabled)
    }

    // MARK: - VFO Tests

    func testSelectVFO() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Select VFO A (FR0) - Kenwood uses FR instead of FT for VFO selection
        let expectedCommand = "FR0;".data(using: .ascii)!
        let response = "FR0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.selectVFO(.a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FR0;")
    }

    func testSelectVFOB() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Select VFO B (FR1) - Different from Yaesu/Elecraft which use FT
        let expectedCommand = "FR1;".data(using: .ascii)!
        let response = "FR1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.selectVFO(.b)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FR1;")
    }

    // MARK: - Power Control Tests

    func testSetPower() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Set power to 50W (50%)
        let expectedCommand = "PC050;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setPower(50)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "PC050;")
    }

    func testGetPower() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Query: PC;
        // Response: PC050; (50%)
        let queryCommand = "PC;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let power = try await kenwoodProtocol.getPower()

        // Full scale is 100W, so 50% = 50W
        XCTAssertEqual(power, 50)
    }

    func testPowerConversion() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Test with 200W radio (TS-990S) - 100W should be 50%
        let protocol200W = KenwoodProtocol(
            transport: mockTransport,
            capabilities: RigCapabilities(
                hasVFOB: true,
                hasSplit: true,
                powerControl: true,
                maxPower: 200,
                supportedModes: [.lsb, .usb],
                frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
                hasDualReceiver: false,
                hasATU: true
            )
        )

        // Set 100W on 200W radio = 50%
        let expectedCommand = "PC050;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await protocol200W.setPower(100)

        let writes = await mockTransport.recordedWrites
        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "PC050;")
    }

    // MARK: - Split Operation Tests

    func testSetSplitOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood uses FT1 for split on
        let expectedCommand = "FT1;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setSplit(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FT1;")
    }

    func testSetSplitOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FT0;".data(using: .ascii)!
        let response = "FT0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setSplit(false)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 1)

        let command = String(data: writes[0], encoding: .ascii)
        XCTAssertEqual(command, "FT0;")
    }

    func testGetSplit() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Query: FT;
        // Response: FT1; (split on)
        let queryCommand = "FT;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let splitEnabled = try await kenwoodProtocol.getSplit()

        XCTAssertTrue(splitEnabled)
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Simulate a complete workflow: Set frequency, mode, and PTT

        // 1. Set frequency
        let freqCmd = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: freqCmd, response: freqCmd)
        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)

        // 2. Set mode to USB
        let modeCmd = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: modeCmd, response: modeCmd)
        try await kenwoodProtocol.setMode(.usb, vfo: .a)

        // 3. Enable PTT
        let pttCmd = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: pttCmd, response: Data())
        try await kenwoodProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        XCTAssertEqual(cmd1, "FA00014230000;")
        XCTAssertEqual(cmd2, "MD2;")
        XCTAssertEqual(cmd3, "TX1;")
    }

    func testSplitOperationWorkflow() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Typical split operation workflow:
        // 1. Enable split
        // 2. Set VFO A frequency (receive)
        // 3. Set VFO B frequency (transmit)
        // 4. Select VFO A for receive

        // 1. Enable split
        let splitOnCmd = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: splitOnCmd, response: splitOnCmd)
        try await kenwoodProtocol.setSplit(true)

        // 2. Set VFO A frequency (RX on 14.230 MHz)
        let vfoACmd = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: vfoACmd, response: vfoACmd)
        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)

        // 3. Set VFO B frequency (TX on 14.235 MHz)
        let vfoBCmd = "FB00014235000;".data(using: .ascii)!
        await mockTransport.setResponse(for: vfoBCmd, response: vfoBCmd)
        try await kenwoodProtocol.setFrequency(14_235_000, vfo: .b)

        // 4. Select VFO A for receive (Kenwood uses FR0)
        let selectCmd = "FR0;".data(using: .ascii)!
        await mockTransport.setResponse(for: selectCmd, response: selectCmd)
        try await kenwoodProtocol.selectVFO(.a)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 4)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)
        let cmd4 = String(data: writes[3], encoding: .ascii)

        XCTAssertEqual(cmd1, "FT1;")           // Split on
        XCTAssertEqual(cmd2, "FA00014230000;") // RX freq
        XCTAssertEqual(cmd3, "FB00014235000;") // TX freq
        XCTAssertEqual(cmd4, "FR0;")           // Select VFO A
    }

    func testDualReceiverRadio() async throws {
        // Test TS-890S which has dual receivers
        let dualRxProtocol = KenwoodProtocol(
            transport: mockTransport,
            capabilities: RigCapabilities(
                hasVFOB: true,
                hasSplit: true,
                powerControl: true,
                maxPower: 100,
                supportedModes: [.lsb, .usb, .cw, .fm, .am],
                frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
                hasDualReceiver: true,
                hasATU: true
            )
        )

        try await dualRxProtocol.connect()
        await mockTransport.reset()

        // Set main receiver (VFO A) to 14.230 MHz
        let mainCmd = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: mainCmd, response: mainCmd)
        try await dualRxProtocol.setFrequency(14_230_000, vfo: .a)

        // Set sub receiver (VFO B) to 7.100 MHz
        let subCmd = "FB00007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: subCmd, response: subCmd)
        try await dualRxProtocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        XCTAssertEqual(writes.count, 2)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)

        XCTAssertEqual(cmd1, "FA00014230000;")
        XCTAssertEqual(cmd2, "FB00007100000;")
    }
}
