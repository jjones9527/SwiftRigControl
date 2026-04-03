import Testing
@testable import RigControl

/// Protocol-level tests for Kenwood text-based CAT communication
@Suite struct KenwoodProtocolTests {
    var mockTransport: MockTransport
    var kenwoodProtocol: KenwoodProtocol

    init() async throws {
        mockTransport = MockTransport()
        kenwoodProtocol = KenwoodProtocol(
            transport: mockTransport,
            capabilities: .full
        )
    }

    // MARK: - Connection Tests

    @Test func connect() async throws {
        // Mock AI0; response (auto-info disable)
        let aiCommand = "AI0;".data(using: .ascii)!
        let aiResponse = "AI0;".data(using: .ascii)!
        await mockTransport.setResponse(for: aiCommand, response: aiResponse)

        try await kenwoodProtocol.connect()

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "AI0;")
    }

    // MARK: - Frequency Tests

    @Test func setFrequency() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Expected command: FA00014230000; (14.230 MHz)
        let expectedCommand = "FA00014230000;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FA00014230000;")
    }

    @Test func getFrequency() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "FA;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let freq = try await kenwoodProtocol.getFrequency(vfo: .a)

        #expect(freq == 14_230_000)
    }

    @Test func setFrequencyVFOB() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FB00007100000;".data(using: .ascii)!
        let response = "FB00007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FB00007100000;")
    }

    // MARK: - Mode Tests

    @Test func setMode() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "MD2;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "MD2;")
    }

    @Test func getMode() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "MD;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let mode = try await kenwoodProtocol.getMode(vfo: .a)

        #expect(mode == .usb)
    }

    @Test func modeMappings() async throws {
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
            #expect(writes.count == 1, "Mode \(mode) failed")

            let command = String(data: writes[0], encoding: .ascii)
            #expect(command == expectedCmd, "Mode \(mode) command mismatch")
        }
    }

    // MARK: - PTT Tests

    @Test func setPTTOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood uses TX1 for PTT on
        let expectedCommand = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await kenwoodProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX1;")
    }

    @Test func setPTTOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood uses TX0 for PTT off
        let expectedCommand = "TX0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await kenwoodProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX0;")
    }

    @Test func getPTT() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "TX;".data(using: .ascii)!
        let response = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let enabled = try await kenwoodProtocol.getPTT()

        #expect(enabled)
    }

    // MARK: - VFO Tests

    @Test func selectVFO() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Select VFO A (FR0) - Kenwood uses FR instead of FT for VFO selection
        let expectedCommand = "FR0;".data(using: .ascii)!
        let response = "FR0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.selectVFO(.a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FR0;")
    }

    @Test func selectVFOB() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Select VFO B (FR1) - Different from Yaesu/Elecraft which use FT
        let expectedCommand = "FR1;".data(using: .ascii)!
        let response = "FR1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.selectVFO(.b)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FR1;")
    }

    // MARK: - Power Control Tests

    @Test func setPower() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "PC050;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setPower(50)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "PC050;")
    }

    @Test func getPower() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "PC;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let power = try await kenwoodProtocol.getPower()

        #expect(power == 50)
    }

    @Test func powerConversion() async throws {
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
        #expect(command == "PC050;")
    }

    // MARK: - Split Operation Tests

    @Test func setSplitOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood uses FT1 for split on
        let expectedCommand = "FT1;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setSplit(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FT1;")
    }

    @Test func setSplitOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FT0;".data(using: .ascii)!
        let response = "FT0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await kenwoodProtocol.setSplit(false)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FT0;")
    }

    @Test func getSplit() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "FT;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let splitEnabled = try await kenwoodProtocol.getSplit()

        #expect(splitEnabled)
    }

    // MARK: - Integration Tests

    @Test func completeWorkflow() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

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
        #expect(writes.count == 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        #expect(cmd1 == "FA00014230000;")
        #expect(cmd2 == "MD2;")
        #expect(cmd3 == "TX1;")
    }

    @Test func splitOperationWorkflow() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

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
        #expect(writes.count == 4)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)
        let cmd4 = String(data: writes[3], encoding: .ascii)

        #expect(cmd1 == "FT1;")           // Split on
        #expect(cmd2 == "FA00014230000;") // RX freq
        #expect(cmd3 == "FB00014235000;") // TX freq
        #expect(cmd4 == "FR0;")           // Select VFO A
    }

    @Test func dualReceiverRadio() async throws {
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
        #expect(writes.count == 2)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)

        #expect(cmd1 == "FA00014230000;")
        #expect(cmd2 == "FB00007100000;")
    }
}
