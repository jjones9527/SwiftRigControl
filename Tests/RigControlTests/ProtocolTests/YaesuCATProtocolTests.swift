import Testing
@testable import RigControl

/// Protocol-level tests for Yaesu CAT communication
@Suite struct YaesuCATProtocolTests {
    var mockTransport: MockTransport
    var yaesuProtocol: YaesuCATProtocol

    init() async throws {
        mockTransport = MockTransport()
        yaesuProtocol = YaesuCATProtocol(
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

        try await yaesuProtocol.connect()

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "AI0;")
    }

    // MARK: - Frequency Tests

    @Test func setFrequency() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FA00014230000;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FA00014230000;")
    }

    @Test func getFrequency() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "FA;".data(using: .ascii)!
        let response = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let freq = try await yaesuProtocol.getFrequency(vfo: .a)

        #expect(freq == 14_230_000)
    }

    @Test func setFrequencyVFOB() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FB00007100000;".data(using: .ascii)!
        let response = "FB00007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FB00007100000;")
    }

    // MARK: - Mode Tests

    @Test func setMode() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "MD2;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "MD2;")
    }

    @Test func getMode() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "MD;".data(using: .ascii)!
        let response = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let mode = try await yaesuProtocol.getMode(vfo: .a)

        #expect(mode == .usb)
    }

    @Test func modeMappings() async throws {
        try await yaesuProtocol.connect()

        let modeMappings: [(Mode, String)] = [
            (.lsb, "MD1;"),
            (.usb, "MD2;"),
            (.cw, "MD3;"),
            (.fm, "MD4;"),
            (.am, "MD5;"),
            (.rtty, "MD6;"),
            (.cwR, "MD7;"),
            (.dataLSB, "MD8;"),
            (.dataUSB, "MD9;"),
        ]

        for (mode, expectedCmd) in modeMappings {
            await mockTransport.reset()

            let expectedCommand = expectedCmd.data(using: .ascii)!
            let response = expectedCmd.data(using: .ascii)!
            await mockTransport.setResponse(for: expectedCommand, response: response)

            try await yaesuProtocol.setMode(mode, vfo: .a)

            let writes = await mockTransport.recordedWrites
            #expect(writes.count == 1, "Mode \(mode) failed")

            let command = String(data: writes[0], encoding: .ascii)
            #expect(command == expectedCmd, "Mode \(mode) command mismatch")
        }
    }

    // MARK: - PTT Tests

    @Test func setPTTOn() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        // Yaesu uses TX1 for PTT on (different from Elecraft's TX)
        let expectedCommand = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await yaesuProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX1;")
    }

    @Test func setPTTOff() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        // Yaesu uses TX0 for PTT off (different from Elecraft's RX)
        let expectedCommand = "TX0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await yaesuProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX0;")
    }

    @Test func getPTT() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "TX;".data(using: .ascii)!
        let response = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let enabled = try await yaesuProtocol.getPTT()

        #expect(enabled)
    }

    // MARK: - VFO Tests

    @Test func selectVFO() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        // Select VFO A (FT0)
        let expectedCommand = "FT0;".data(using: .ascii)!
        let response = "FT0;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.selectVFO(.a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FT0;")
    }

    @Test func selectVFOB() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        // Select VFO B (FT1)
        let expectedCommand = "FT1;".data(using: .ascii)!
        let response = "FT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.selectVFO(.b)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FT1;")
    }

    // MARK: - Power Control Tests

    @Test func setPower() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "PC050;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.setPower(50)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "PC050;")
    }

    @Test func getPower() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "PC;".data(using: .ascii)!
        let response = "PC050;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let power = try await yaesuProtocol.getPower()

        #expect(power == 50)
    }

    // MARK: - Split Operation Tests

    @Test func setSplitOn() async throws {
        // Split via `ST` is only supported on FTDX-10 / FT-DX101(D/MP)
        // / FT-710 / FT-450 per Hamlib newcat.c:578. Use those quirks
        // for this test.
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock, capabilities: .full, quirks: .newcatWithSTDX
        )
        try await yaesu.connect()
        await mock.reset()

        let expectedCommand = "ST1;".data(using: .ascii)!
        let response = "ST1;".data(using: .ascii)!
        await mock.setResponse(for: expectedCommand, response: response)

        try await yaesu.setSplit(true)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "ST1;")
    }

    @Test func setSplitOff() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock, capabilities: .full, quirks: .newcatWithSTDX
        )
        try await yaesu.connect()
        await mock.reset()

        let expectedCommand = "ST0;".data(using: .ascii)!
        let response = "ST0;".data(using: .ascii)!
        await mock.setResponse(for: expectedCommand, response: response)

        try await yaesu.setSplit(false)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "ST0;")
    }

    @Test func getSplit() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock, capabilities: .full, quirks: .newcatWithSTDX
        )
        try await yaesu.connect()
        await mock.reset()

        let queryCommand = "ST;".data(using: .ascii)!
        let response = "ST1;".data(using: .ascii)!
        await mock.setResponse(for: queryCommand, response: response)

        let splitEnabled = try await yaesu.getSplit()

        #expect(splitEnabled)
    }

    // MARK: - Integration Tests

    @Test func completeWorkflow() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        // 1. Set frequency
        let freqCmd = "FA00014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: freqCmd, response: freqCmd)
        try await yaesuProtocol.setFrequency(14_230_000, vfo: .a)

        // 2. Set mode to USB
        let modeCmd = "MD2;".data(using: .ascii)!
        await mockTransport.setResponse(for: modeCmd, response: modeCmd)
        try await yaesuProtocol.setMode(.usb, vfo: .a)

        // 3. Enable PTT
        let pttCmd = "TX1;".data(using: .ascii)!
        await mockTransport.setResponse(for: pttCmd, response: Data())
        try await yaesuProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        #expect(cmd1 == "FA00014230000;")
        #expect(cmd2 == "MD2;")
        #expect(cmd3 == "TX1;")
    }

    @Test func splitOperation() async throws {
        // Use ST-capable quirks for this split integration test.
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock, capabilities: .full, quirks: .newcatWithSTDX
        )
        try await yaesu.connect()
        await mock.reset()

        // 1. Enable split via ST1 (not FT1 — see fix for #12 audit)
        let splitOnCmd = "ST1;".data(using: .ascii)!
        await mock.setResponse(for: splitOnCmd, response: splitOnCmd)
        try await yaesu.setSplit(true)

        // 2. Set VFO A frequency (RX)
        let vfoACmd = "FA00014230000;".data(using: .ascii)!
        await mock.setResponse(for: vfoACmd, response: vfoACmd)
        try await yaesu.setFrequency(14_230_000, vfo: .a)

        // 3. Set VFO B frequency (TX)
        let vfoBCmd = "FB00014235000;".data(using: .ascii)!
        await mock.setResponse(for: vfoBCmd, response: vfoBCmd)
        try await yaesu.setFrequency(14_235_000, vfo: .b)

        let writes = await mock.recordedWrites
        #expect(writes.count == 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        #expect(cmd1 == "ST1;")
        #expect(cmd2 == "FA00014230000;")
        #expect(cmd3 == "FB00014235000;")
    }

    // MARK: - VFO operations (v1.1 parity)

    @Test func vfoOpExchange() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        try await yaesuProtocol.performVFOOperation(.exchange)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "SV;")
    }

    @Test func vfoOpCopyVFO() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        try await yaesuProtocol.performVFOOperation(.copyVFO)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "AB;")
    }

    @Test func vfoOpVFOToMemory() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        try await yaesuProtocol.performVFOOperation(.vfoToMemory)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "AM;")
    }

    @Test func vfoOpTune() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        try await yaesuProtocol.performVFOOperation(.tune)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "AC002;")
    }

    @Test func vfoOpMemoryClearUnsupported() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        await #expect(throws: RigError.self) {
            try await yaesuProtocol.performVFOOperation(.memoryClear)
        }
    }

    // MARK: - Function toggles (v1.1 parity)

    @Test func setFunctionCompressorOn() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        try await yaesuProtocol.setFunction(.compressor, enabled: true)
        #expect(String(data: await mockTransport.recordedWrites[0], encoding: .ascii) == "PR01;")
    }

    @Test func setFunctionAutoNotch() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        try await yaesuProtocol.setFunction(.autoNotch, enabled: true)
        #expect(String(data: await mockTransport.recordedWrites[0], encoding: .ascii) == "BC01;")
    }

    @Test func setFunctionAfcUnsupported() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()
        await #expect(throws: RigError.self) {
            try await yaesuProtocol.setFunction(.autoFrequencyControl, enabled: true)
        }
    }
}
