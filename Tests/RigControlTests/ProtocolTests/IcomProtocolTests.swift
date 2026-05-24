import Testing
@testable import RigControl

/// Protocol-level tests for Icom CI-V communication
@Suite struct IcomProtocolTests {
    var mockTransport: MockTransport
    var icomProtocol: IcomCIVProtocol

    init() async throws {
        mockTransport = MockTransport()
        // The byte sequences these tests assert against come from a
        // generic Icom-CI-V radio (targetable VFO model, FIL1 byte on
        // mode commands, no echo). That matches StandardIcomCommandSet
        // — the original test fixture used the legacy single-init form
        // that synthesised exactly this command set. Keep the explicit
        // construction now that the legacy init is gone.
        icomProtocol = IcomCIVProtocol(
            transport: mockTransport,
            civAddress: 0xA2,
            radioModel: .ic9700,
            commandSet: StandardIcomCommandSet(civAddress: 0xA2),
            capabilities: .full
        )
        try await icomProtocol.connect()
    }

    // MARK: - PTT Tests

    @Test func setPTTOn() async throws {
        // PTT command: 0x1C sub-command 0x00, data 0x01 (transmit)
        // Wire format: FE FE A2 E0 1C 00 01 FD
        let expectedCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x00, 0x01, 0xFD])

        // Mock ACK response: FE FE E0 A2 FB FD
        let ackResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expectedCommand, response: ackResponse)

        try await icomProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expectedCommand)
    }

    @Test func setPTTOff() async throws {
        // PTT command: 0x1C sub-command 0x00, data 0x00 (receive)
        // Wire format: FE FE A2 E0 1C 00 00 FD
        let expectedCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x00, 0x00, 0xFD])

        // Mock ACK response
        let ackResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expectedCommand, response: ackResponse)

        try await icomProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expectedCommand)
    }

    @Test func getPTT() async throws {
        // PTT read command: 0x1C sub-command 0x00
        // Wire format: FE FE A2 E0 1C 00 FD
        let expectedQuery = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x00, 0xFD])

        // Mock response indicating PTT is ON: FE FE E0 A2 1C 00 01 FD
        let response = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x1C, 0x00, 0x01, 0xFD])
        await mockTransport.setResponse(for: expectedQuery, response: response)

        let result = try await icomProtocol.getPTT()

        #expect(result)
    }

    // MARK: - Frequency Tests

    @Test func setFrequency() async throws {
        // First, mock VFO selection
        let vfoCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0x00, 0xFD])
        let vfoAck = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: vfoCommand, response: vfoAck)

        // Then, mock frequency set (14.230 MHz)
        let freqCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x05, 0x00, 0x00, 0x23, 0x14, 0x00, 0xFD])
        await mockTransport.setResponse(for: freqCommand, response: vfoAck)

        try await icomProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 2)
        #expect(writes[1] == freqCommand)
    }

    @Test func getFrequency() async throws {
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

        #expect(result == 14_230_000)
    }

    // MARK: - Mode Tests

    @Test func setMode() async throws {
        // Mock VFO selection
        let vfoCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0x00, 0xFD])
        let vfoAck = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: vfoCommand, response: vfoAck)

        // Mock mode set to USB (0x01) with FIL1 filter byte (0x01)
        let modeCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x06, 0x01, 0x01, 0xFD])
        await mockTransport.setResponse(for: modeCommand, response: vfoAck)

        try await icomProtocol.setMode(.usb, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 2)
        #expect(writes[1] == modeCommand)
    }

    @Test func getMode() async throws {
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

        #expect(result == .usb)
    }

    // MARK: - Error Handling Tests

    @Test func commandFailedOnNak() async throws {
        // Mock NAK response: FE FE E0 A2 FA FD
        let nakResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFA, 0xFD])
        let pttCommand = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x00, 0x01, 0xFD])
        await mockTransport.setResponse(for: pttCommand, response: nakResponse)

        await #expect(throws: RigError.self) {
            try await icomProtocol.setPTT(true)
        }
    }

    @Test func timeoutOnRead() async throws {
        await mockTransport.reset()
        await mockTransport.setShouldThrowOnRead(true)

        await #expect(throws: RigError.self) {
            try await icomProtocol.setPTT(true)
        }
    }

    // MARK: - VFO operations (v1.1 parity)

    @Test func vfoOpExchange() async throws {
        // Wire: FE FE A2 E0 07 B0 FD  (0x07/0xB0 = S_XCHNG)
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0xB0, 0xFD])
        let ack = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expected, response: ack)

        try await icomProtocol.performVFOOperation(.exchange)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expected)
    }

    @Test func vfoOpCopy() async throws {
        // 0x07/0xA0 = S_BTOA (active → other VFO).
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0xA0, 0xFD])
        let ack = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expected, response: ack)

        try await icomProtocol.performVFOOperation(.copyVFO)
        #expect(await mockTransport.recordedWrites.last == expected)
    }

    @Test func vfoOpVFOToMemory() async throws {
        // 0x09 = C_WR_MEM
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x09, 0xFD])
        let ack = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expected, response: ack)

        try await icomProtocol.performVFOOperation(.vfoToMemory)
        #expect(await mockTransport.recordedWrites.last == expected)
    }

    @Test func vfoOpMemoryToVFO() async throws {
        // 0x0A = C_MEM2VFO
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x0A, 0xFD])
        let ack = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expected, response: ack)

        try await icomProtocol.performVFOOperation(.memoryToVFO)
        #expect(await mockTransport.recordedWrites.last == expected)
    }

    @Test func vfoOpMemoryClear() async throws {
        // 0x0B = C_CLR_MEM
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x0B, 0xFD])
        let ack = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expected, response: ack)

        try await icomProtocol.performVFOOperation(.memoryClear)
        #expect(await mockTransport.recordedWrites.last == expected)
    }

    @Test func vfoOpTune() async throws {
        // 0x1C 0x01 0x02 = start ATU tune cycle.
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x1C, 0x01, 0x02, 0xFD])
        let ack = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        await mockTransport.setResponse(for: expected, response: ack)

        try await icomProtocol.performVFOOperation(.tune)
        #expect(await mockTransport.recordedWrites.last == expected)
    }

    @Test func vfoOpUnsupportedStepThrows() async throws {
        // Icom has no CI-V equivalent for stepUp/stepDown — should
        // surface as an explicit unsupportedOperation rather than
        // silently NAKing.
        await #expect(throws: RigError.self) {
            try await icomProtocol.performVFOOperation(.stepUp)
        }
    }

    @Test func vfoOpRadioNakRaisesCommandFailed() async throws {
        let expected = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x07, 0xB0, 0xFD])
        // NAK frame (0xFA instead of 0xFB).
        let nak = Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFA, 0xFD])
        await mockTransport.setResponse(for: expected, response: nak)

        await #expect(throws: RigError.self) {
            try await icomProtocol.performVFOOperation(.exchange)
        }
    }
}

// Helper extension for MockTransport testing
extension MockTransport {
    func setProperty<T>(_ keyPath: ReferenceWritableKeyPath<MockTransport, T>, to value: T) {
        self[keyPath: keyPath] = value
    }
}
