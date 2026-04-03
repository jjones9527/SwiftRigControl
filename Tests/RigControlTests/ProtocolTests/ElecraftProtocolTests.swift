import Testing
@testable import RigControl

/// Protocol-level tests for Elecraft text-based CAT communication
@Suite struct ElecraftProtocolTests {
    var mockTransport: MockTransport
    var elecraftProtocol: ElecraftProtocol

    init() async throws {
        mockTransport = MockTransport()
        elecraftProtocol = ElecraftProtocol(
            transport: mockTransport,
            capabilities: .full
        )
    }

    // MARK: - Connection Tests

    @Test func connect() async throws {
        // Mock AI0; response
        let aiCommand = "AI0;".data(using: .ascii)!
        let aiResponse = "AI0;".data(using: .ascii)!
        await mockTransport.setResponse(for: aiCommand, response: aiResponse)

        try await elecraftProtocol.connect()

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "AI0;")
    }

    // MARK: - Frequency Tests

    @Test func setFrequency() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Expected command: FA00014230000; (14.230 MHz)
        let expectedCommand = "FA00014230000;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await elecraftProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FA00014230000;")
    }

    @Test func getFrequency() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Query: FA;
        // Response: FA00014230000;
        let queryCommand = "FA;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let freq = try await elecraftProtocol.getFrequency(vfo: .a)

        #expect(freq == 14_230_000)
    }

    @Test func setFrequencyVFOB() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Expected command: FB00007100000; (7.100 MHz)
        let expectedCommand = "FB00007100000;".data(using: .ascii)!
        let response = "FB00007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await elecraftProtocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FB00007100000;")
    }

    // MARK: - Mode Tests

    @Test func setMode() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Set mode to USB (code 2)
        let expectedCommand = "MD2;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await elecraftProtocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "MD2;")
    }

    @Test func getMode() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Query: MD;
        // Response: MD2; (USB)
        let queryCommand = "MD;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let mode = try await elecraftProtocol.getMode(vfo: .a)

        #expect(mode == .usb)
    }

    @Test func modeMappings() async throws {
        try await elecraftProtocol.connect()

        let modeMappings: [(Mode, String)] = [
            (.lsb, "MD1;"),
            (.usb, "MD2;"),
            (.cw, "MD3;"),
            (.fm, "MD4;"),
            (.am, "MD5;"),
            (.dataUSB, "MD6;"),
            (.cwR, "MD7;"),
            (.rtty, "MD8;"),
            (.dataLSB, "MD9;"),
        ]

        for (mode, expectedCmd) in modeMappings {
            await mockTransport.reset()

            let expectedCommand = expectedCmd.data(using: .ascii)!
            let response = expectedCmd.data(using: .ascii)!
            await mockTransport.setResponse(for: expectedCommand, response: response)

            try await elecraftProtocol.setMode(mode, vfo: .a)

            let writes = await mockTransport.recordedWrites
            #expect(writes.count == 1, "Mode \(mode) failed")

            let command = String(data: writes[0], encoding: .ascii)
            #expect(command == expectedCmd, "Mode \(mode) command mismatch")
        }
    }

    // MARK: - PTT Tests

    @Test func setPTTOn() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // PTT commands may not get a response
        let expectedCommand = "TX;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await elecraftProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX;")
    }

    @Test func setPTTOff() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "RX;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await elecraftProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "RX;")
    }

    // MARK: - VFO Tests

    @Test func selectVFO() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Select VFO A (FR0 and FT0)
        let frCommand = "FR0;".data(using: .ascii)!
        let frResponse = "FR0;".data(using: .ascii)!
        let ftCommand = "FT0;".data(using: .ascii)!
        let ftResponse = "FT0;".data(using: .ascii)!
        await mockTransport.setResponse(for: frCommand, response: frResponse)
        await mockTransport.setResponse(for: ftCommand, response: ftResponse)

        try await elecraftProtocol.selectVFO(.a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 2)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        #expect(cmd1 == "FR0;")
        #expect(cmd2 == "FT0;")
    }

    // MARK: - Power Control Tests

    @Test func setPower() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Set power to 50W (50%)
        let expectedCommand = "PC050;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await elecraftProtocol.setPower(50)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "PC050;")
    }

    @Test func getPower() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Query: PC;
        // Response: PC050; (50%)
        let queryCommand = "PC;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let power = try await elecraftProtocol.getPower()

        // Full scale is 100W, so 50% = 50W
        #expect(power == 50)
    }

    // MARK: - Split Operation Tests

    @Test func setSplitOn() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Split: FR0 (RX on VFO A) and FT1 (TX on VFO B)
        let frCommand = "FR0;".data(using: .ascii)!
        let frResponse = "FR0;".data(using: .ascii)!
        let ftCommand = "FT1;".data(using: .ascii)!
        let ftResponse = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: frCommand, response: frResponse)
        await mockTransport.setResponse(for: ftCommand, response: ftResponse)

        try await elecraftProtocol.setSplit(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 2)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        #expect(cmd1 == "FR0;")
        #expect(cmd2 == "FT1;")
    }

    @Test func getSplit() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Query: FT;
        // Response: FT1; (split on)
        let queryCommand = "FT;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let splitEnabled = try await elecraftProtocol.getSplit()

        #expect(splitEnabled)
    }

    // MARK: - Integration Tests

    @Test func completeWorkflow() async throws {
        try await elecraftProtocol.connect()
        await mockTransport.reset()

        // Simulate a complete workflow: Set frequency, mode, and PTT

        // 1. Set frequency
        let freqCmd = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: freqCmd, response: freqCmd)
        try await elecraftProtocol.setFrequency(14_230_000, vfo: .a)

        // 2. Set mode to USB
        let modeCmd = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: modeCmd, response: modeCmd)
        try await elecraftProtocol.setMode(.usb, vfo: .a)

        // 3. Enable PTT
        let pttCmd = "TX;".data(using: .ascii)!
        await mockTransport.setResponse(for: pttCmd, response: Data())
        try await elecraftProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        #expect(cmd1 == "FA00014230000;")
        #expect(cmd2 == "MD2;")
        #expect(cmd3 == "TX;")
    }
}
