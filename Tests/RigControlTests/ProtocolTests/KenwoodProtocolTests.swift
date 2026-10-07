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

    /// Kenwood set commands produce no reply; KenwoodProtocol confirms
    /// each one with `ID;` (Hamlib `kenwood.c:427-443`). Answer it the
    /// way a TS-2000 does. Call after `mockTransport.reset()`, which
    /// clears stubbed responses.
    private func stubIDReply() async {
        await mockTransport.setResponse(for: "ID;".data(using: .ascii)!,
                                        response: "ID019;".data(using: .ascii)!)
    }

    private func sentCommands() async -> [String] {
        await mockTransport.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
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
        await stubIDReply()
        // Expected command: FA00014230000; (14.230 MHz)

        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)

        #expect(await sentCommands() == ["FA00014230000;", "ID;"])
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
        await stubIDReply()
    // MARK: - Mode Tests

        try await kenwoodProtocol.setFrequency(7_100_000, vfo: .b)

        #expect(await sentCommands() == ["FB00007100000;", "ID;"])
    }

    @Test func setMode() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()

        try await kenwoodProtocol.setMode(.usb, vfo: .a)

        #expect(await sentCommands() == ["MD2;", "ID;"])
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
        // Shared Kenwood table, Hamlib `rigs/kenwood/kenwood.c`
        // `kenwood_mode_table` (lines 142-168). `.standard` style
        // radios have no DATA modes (see KenwoodModeStyleTests).
        try await kenwoodProtocol.connect()

        let modeMappings: [(Mode, String)] = [
            (.lsb, "MD1;"),
            (.usb, "MD2;"),
            (.cw, "MD3;"),
            (.fm, "MD4;"),
            (.am, "MD5;"),
            (.rtty, "MD6;"),
            (.cwR, "MD7;"),
            // 8 = RIG_MODE_NONE (TUNE) — no direct Mode equivalent.
            (.rttyR, "MD9;"),
        ]

        for (mode, expectedCmd) in modeMappings {
            await mockTransport.reset()
            await stubIDReply()

            try await kenwoodProtocol.setMode(mode, vfo: .a)

            #expect(await sentCommands() == [expectedCmd, "ID;"], "Mode \(mode) command mismatch")
        }
    }

    // MARK: - PTT Tests

    @Test func setPTTOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood PTT-on is bare `TX;` per Hamlib `kenwood_set_ptt`.
        // (Pre-fix code sent `TX1;` which means "PTT via data port"
        // — also a keying command, but not the canonical form.)
        let expectedCommand = "TX;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await kenwoodProtocol.setPTT(true)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX;")
    }

    @Test func setPTTOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // Kenwood PTT-off is bare `RX;` per Hamlib `kenwood_set_ptt`.
        // (Pre-fix code sent `TX0;` which on Kenwood actually means
        // "PTT on via mic port" — the exact opposite of RX. This
        // was the most dangerous of the audited PTT bugs.)
        let expectedCommand = "RX;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: Data())

        try await kenwoodProtocol.setPTT(false)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "RX;")
    }

    @Test func getPTT() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()

        // PTT is read from the `IF;` response byte 28 per Hamlib
        // `kenwood_get_ptt`. Pre-fix code queried `TX;` which on
        // Kenwood *sets* PTT — every poll would key the radio.
        let queryCommand = "IF;".data(using: .ascii)!

        // 37-char IF response with byte 28 = '1' (transmitting).
        var chars = Array(repeating: Character("0"), count: 37)
        chars[0] = "I"; chars[1] = "F"; chars[28] = "1"
        let response = (String(chars) + ";").data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let enabled = try await kenwoodProtocol.getPTT()

        #expect(enabled)
    }

    // MARK: - VFO Tests

    @Test func selectVFO() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        // Select VFO A (FR0) - Kenwood uses FR instead of FT for VFO selection

        try await kenwoodProtocol.selectVFO(.a)

        #expect(await sentCommands() == ["FR0;", "ID;"])
    }

    @Test func selectVFOB() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        // Select VFO B (FR1) - Different from Yaesu/Elecraft which use FT
    // MARK: - Power Control Tests

        try await kenwoodProtocol.selectVFO(.b)

        #expect(await sentCommands() == ["FR1;", "ID;"])
    }

    @Test func setPower() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()

        try await kenwoodProtocol.setPower(50)

        #expect(await sentCommands() == ["PC050;", "ID;"])
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
        await stubIDReply()

        try await protocol200W.setPower(100)

        let writes = await mockTransport.recordedWrites
        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "PC050;")
    }

    // MARK: - Split Operation Tests

    @Test func setSplitOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        // Kenwood uses FT1 for split on

        try await kenwoodProtocol.setSplit(true)

        #expect(await sentCommands() == ["FT1;", "ID;"])
    }

    @Test func setSplitOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()

        try await kenwoodProtocol.setSplit(false)

        #expect(await sentCommands() == ["FT0;", "ID;"])
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
        await stubIDReply()

        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)
        try await kenwoodProtocol.setMode(.usb, vfo: .a)
        // PTT is bare `TX;` per Hamlib canonical form, without ID;
        // verification (unchanged; see setPTT).
        try await kenwoodProtocol.setPTT(true)

        #expect(await sentCommands() == [
            "FA00014230000;", "ID;",
            "MD2;", "ID;",
            "TX;",
        ])
    }

    @Test func splitOperationWorkflow() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()

        try await kenwoodProtocol.setSplit(true)
        try await kenwoodProtocol.setFrequency(14_230_000, vfo: .a)
        try await kenwoodProtocol.setFrequency(14_235_000, vfo: .b)
        // Kenwood uses FR0 to select VFO A for receive.
        try await kenwoodProtocol.selectVFO(.a)

        #expect(await sentCommands() == [
            "FT1;", "ID;",            // Split on
            "FA00014230000;", "ID;",  // RX freq
            "FB00014235000;", "ID;",  // TX freq
            "FR0;", "ID;",            // Select VFO A
        ])
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
        await stubIDReply()

        // Main receiver (VFO A) to 14.230 MHz, sub (VFO B) to 7.100 MHz.
        try await dualRxProtocol.setFrequency(14_230_000, vfo: .a)
        try await dualRxProtocol.setFrequency(7_100_000, vfo: .b)

        #expect(await sentCommands() == [
            "FA00014230000;", "ID;",
            "FB00007100000;", "ID;",
        ])
    }

    // MARK: - VFO operations (v1.1 parity)

    @Test func vfoOpStepUp() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        try await kenwoodProtocol.performVFOOperation(.stepUp)

        #expect(await sentCommands() == ["UP;", "ID;"])
    }

    @Test func vfoOpBandDown() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        try await kenwoodProtocol.performVFOOperation(.bandDown)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "BD;")
    }

    @Test func vfoOpMemoryToVFO() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        try await kenwoodProtocol.performVFOOperation(.memoryToVFO)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "MR;")
    }

    @Test func vfoOpTune() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        try await kenwoodProtocol.performVFOOperation(.tune)

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[0], encoding: .ascii) == "AC111;")
    }

    @Test func vfoOpUnsupportedExchangeThrows() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await #expect(throws: RigError.self) {
            try await kenwoodProtocol.performVFOOperation(.exchange)
        }
    }

    // MARK: - Function toggles (v1.1 parity)

    @Test func setFunctionCompressorOn() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        try await kenwoodProtocol.setFunction(.compressor, enabled: true)

        #expect(String(data: await mockTransport.recordedWrites[0], encoding: .ascii) == "PR1;")
    }

    @Test func setFunctionTunerOff() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await stubIDReply()
        try await kenwoodProtocol.setFunction(.tuner, enabled: false)

        #expect(String(data: await mockTransport.recordedWrites[0], encoding: .ascii) == "AC110;")
    }

    @Test func getFunctionLockReturnsTrue() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        let query = "LK;".data(using: .ascii)!
        let response = "LK1;".data(using: .ascii)!
        await mockTransport.setResponse(for: query, response: response)

        let on = try await kenwoodProtocol.getFunction(.lock)
        #expect(on == true)
    }

    @Test func setFunctionSatModeUnsupported() async throws {
        try await kenwoodProtocol.connect()
        await mockTransport.reset()
        await #expect(throws: RigError.self) {
            try await kenwoodProtocol.setFunction(.satelliteMode, enabled: true)
        }
    }
}
