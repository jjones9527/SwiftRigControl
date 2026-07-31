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

        let expectedCommand = "FA014230000;".data(using: .ascii)!
        let response = "FA014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.setFrequency(14_230_000, vfo: .a)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FA014230000;")
    }

    @Test func getFrequency() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let queryCommand = "FA;".data(using: .ascii)!
        let response = "FA014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: queryCommand, response: response)

        let freq = try await yaesuProtocol.getFrequency(vfo: .a)

        #expect(freq == 14_230_000)
    }

    @Test func setFrequencyVFOB() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCommand = "FB007100000;".data(using: .ascii)!
        let response = "FB007100000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCommand, response: response)

        try await yaesuProtocol.setFrequency(7_100_000, vfo: .b)

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 1)

        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "FB007100000;")
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
        let freqCmd = "FA014230000;".data(using: .ascii)!
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

        #expect(cmd1 == "FA014230000;")
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
        let vfoACmd = "FA014230000;".data(using: .ascii)!
        await mock.setResponse(for: vfoACmd, response: vfoACmd)
        try await yaesu.setFrequency(14_230_000, vfo: .a)

        // 3. Set VFO B frequency (TX)
        let vfoBCmd = "FB014235000;".data(using: .ascii)!
        await mock.setResponse(for: vfoBCmd, response: vfoBCmd)
        try await yaesu.setFrequency(14_235_000, vfo: .b)

        let writes = await mock.recordedWrites
        #expect(writes.count == 3)

        let cmd1 = String(data: writes[0], encoding: .ascii)
        let cmd2 = String(data: writes[1], encoding: .ascii)
        let cmd3 = String(data: writes[2], encoding: .ascii)

        #expect(cmd1 == "ST1;")
        #expect(cmd2 == "FA014230000;")
        #expect(cmd3 == "FB014235000;")
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

    // MARK: - Frequency-format regression (v1.2.0 fix)
    //
    // Prior to v1.2.0 the FA/FB commands used an 11-digit format
    // (FA00014230000;) that no real Yaesu radio accepts. The correct
    // newcat format is 9-digit (FA014230000;) per Hamlib
    // `rigs/yaesu/newcat.c` — Hamlib's SNPRINTF(..., "FA%09.0f;", ...)
    // sites at newcat.c lines ~1587 and ~1592 plus the variable-width
    // dispatch in `newcat_set_freq` (width_frequency = 8 or 9 based on
    // the IF response length). These tests guard against that class
    // of format-string regression.

    @Test func setFrequencyDefaultsToNineDigitNewcatFormat() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCmd = "FA014230000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCmd, response: expectedCmd)

        try await yaesuProtocol.setFrequency(14_230_000, vfo: .a)

        let cmd = String(data: await mockTransport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "FA014230000;")
    }

    @Test func setFrequencyZeroPadsLowFrequencyToNineDigits() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expectedCmd = "FA001800000;".data(using: .ascii)!
        await mockTransport.setResponse(for: expectedCmd, response: expectedCmd)

        try await yaesuProtocol.setFrequency(1_800_000, vfo: .a)   // 160m

        let cmd = String(data: await mockTransport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "FA001800000;")
    }

    // MARK: - FTX-1 quirks (v1.2.0)

    @Test func ftx1SetFrequencyEmitsMemoryModeEscapeThenNineDigitFA() async throws {
        // FTX-1 requires an SV0; prelude before FA/FB set commands
        // because FA/FB are silently ignored while Main is in Memory
        // mode. See `Quirks.ftx1` for the Hamlib source citation.
        let transport = MockTransport()
        let ftx1 = YaesuCATProtocol(
            transport: transport,
            capabilities: .full,
            quirks: .ftx1
        )
        try await ftx1.connect()
        await transport.reset()

        let svCmd = "SV0;".data(using: .ascii)!
        let faCmd = "FA014230000;".data(using: .ascii)!
        await transport.setResponse(for: svCmd, response: svCmd)
        await transport.setResponse(for: faCmd, response: faCmd)

        try await ftx1.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        // Two writes expected: SV0; then FA014230000;
        #expect(writes.count == 2)
        #expect(String(data: writes[0], encoding: .ascii) == "SV0;")
        #expect(String(data: writes[1], encoding: .ascii) == "FA014230000;")
    }

    @Test func ftx1SetModeMapsCWToCode3() async throws {
        // On FTX-1, MD code 3 = CW-USB (not CW as in the shared
        // newcat table where 3 = CW-R). Swift .cw maps to the
        // FTX-1's CW-USB per `Quirks.ftx1.modeCodeTable`.
        let transport = MockTransport()
        let ftx1 = YaesuCATProtocol(
            transport: transport,
            capabilities: .full,
            quirks: .ftx1
        )
        try await ftx1.connect()
        await transport.reset()

        let svCmd = "SV0;".data(using: .ascii)!
        let mdCmd = "MD3;".data(using: .ascii)!
        await transport.setResponse(for: svCmd, response: svCmd)
        await transport.setResponse(for: mdCmd, response: mdCmd)

        try await ftx1.setMode(.cw, vfo: .a)

        let writes = await transport.recordedWrites
        // SV0; prelude then MD3;
        #expect(writes.count == 2)
        #expect(String(data: writes[0], encoding: .ascii) == "SV0;")
        #expect(String(data: writes[1], encoding: .ascii) == "MD3;")
    }

    @Test func ftx1SetModeMapsCWReverseToCode7() async throws {
        // FTX-1: MD code 7 = CW-LSB (Swift .cwR).
        let transport = MockTransport()
        let ftx1 = YaesuCATProtocol(
            transport: transport,
            capabilities: .full,
            quirks: .ftx1
        )
        try await ftx1.connect()
        await transport.reset()

        let svCmd = "SV0;".data(using: .ascii)!
        let mdCmd = "MD7;".data(using: .ascii)!
        await transport.setResponse(for: svCmd, response: svCmd)
        await transport.setResponse(for: mdCmd, response: mdCmd)

        try await ftx1.setMode(.cwR, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(String(data: writes[1], encoding: .ascii) == "MD7;")
    }

    @Test func ftx1GetFrequencyDecodesNineDigitResponse() async throws {
        let transport = MockTransport()
        let ftx1 = YaesuCATProtocol(
            transport: transport,
            capabilities: .full,
            quirks: .ftx1
        )
        try await ftx1.connect()
        await transport.reset()

        let query = "FA;".data(using: .ascii)!
        let response = "FA014230000;".data(using: .ascii)!
        await transport.setResponse(for: query, response: response)

        let freq = try await ftx1.getFrequency(vfo: .a)

        #expect(freq == 14_230_000)
    }

    // MARK: - v1.2.0 audit fixes — level controls
    //
    // These commands (GT / RG / SH / RU / RD) were emitted in a wire
    // format no real Yaesu radio accepts. Each fix is documented in
    // the CHANGELOG for v1.2.0 audit-fixes with a Hamlib source
    // citation. These tests guard against regression.

    @Test func setAGCFastEmits2DigitGT01() async throws {
        // Per Hamlib newcat.c:4142-4158, GT uses 2-digit fixed codes:
        // GT00=OFF, GT01=FAST, GT02=MEDIUM, GT03=SLOW, GT04=AUTO.
        // Prior code emitted GT000 (3-digit) with Fast=0 mapping.
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expected = "GT01;".data(using: .ascii)!
        await mockTransport.setResponse(for: expected, response: expected)

        try await yaesuProtocol.setAGC(.fast)

        let cmd = String(data: await mockTransport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "GT01;")
    }

    @Test func setAGCAutoEmitsGT04() async throws {
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expected = "GT04;".data(using: .ascii)!
        await mockTransport.setResponse(for: expected, response: expected)

        try await yaesuProtocol.setAGC(.auto)

        let cmd = String(data: await mockTransport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "GT04;")
    }

    @Test func setRFGainEmitsVFOQualifiedFormat() async throws {
        // Per Hamlib newcat.c:4477: RG%c%03d — VFO qualifier byte
        // required. Prior code emitted RG%03d without qualifier.
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expected = "RG0128;".data(using: .ascii)!
        await mockTransport.setResponse(for: expected, response: expected)

        try await yaesuProtocol.setRFGain(128)

        let cmd = String(data: await mockTransport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "RG0128;")
    }

    @Test func setIFFilterEmitsVFOQualifiedSH() async throws {
        // Default fixture uses `.classic` quirks, which resolves to
        // `SHCommandStyle.qualifierOnly` — `SH%c%02d;` with the main
        // VFO byte `0`. Prior to the v1.2.0 audit fix Swift emitted
        // `SH%02d;` without the qualifier — real newcat radios
        // reject that. See Hamlib newcat.c:9218.
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let expected = "SH007;".data(using: .ascii)!
        await mockTransport.setResponse(for: expected, response: expected)

        try await yaesuProtocol.setIFFilter(.filter1)  // wide

        let cmd = String(data: await mockTransport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH007;")
    }

    // MARK: - SH per-family variants (v1.2.2)

    /// Helper: build a fresh YaesuCATProtocol with a specific quirks
    /// preset, connected against a fresh MockTransport.
    private func makeYaesuProtocol(
        quirks: YaesuCATProtocol.Quirks
    ) async throws -> (MockTransport, YaesuCATProtocol) {
        let transport = MockTransport()
        let proto = YaesuCATProtocol(
            transport: transport,
            capabilities: .full,
            quirks: quirks
        )
        try await proto.connect()
        await transport.reset()
        return (transport, proto)
    }

    @Test func setIFFilterEmitsDoubleZeroForFTDX10Family() async throws {
        // FTDX-10 / FT-710 / FTX-1 want `SH00%02d;` — literal
        // double-zero prefix. Hamlib newcat.c:9214.
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ftdx10Family)

        let expected = "SH0007;".data(using: .ascii)!
        await transport.setResponse(for: expected, response: expected)

        try await proto.setIFFilter(.filter1)   // wide

        let cmd = String(data: await transport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH0007;")
    }

    @Test func setIFFilterEmitsDoubleZeroForFT710() async throws {
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ft710)

        let expected = "SH0002;".data(using: .ascii)!
        await transport.setResponse(for: expected, response: expected)

        try await proto.setIFFilter(.filter3)   // narrow

        let cmd = String(data: await transport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH0002;")
    }

    @Test func setIFFilterEmitsDoubleZeroForFTX1() async throws {
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ftx1)

        let expected = "SH0005;".data(using: .ascii)!
        await transport.setResponse(for: expected, response: expected)

        try await proto.setIFFilter(.filter2)   // medium

        let cmd = String(data: await transport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH0005;")
    }

    @Test func setIFFilterEmitsVFOAndNarrowForFTDX101Family() async throws {
        // FTDX-101D/MP want `SH%c%d%02d;` — VFO byte + narrow flag
        // + 2-digit high-cut. Our IFFilter API has no off-state so
        // the flag is always `1`. Hamlib newcat.c:9205-9207.
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ftdx101Family)

        let expected = "SH0107;".data(using: .ascii)!
        await transport.setResponse(for: expected, response: expected)

        try await proto.setIFFilter(.filter1)   // wide

        let cmd = String(data: await transport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH0107;")
    }

    @Test func setIFFilterEmitsVFOAndNarrowForFT891() async throws {
        // FT-891 shares the `.vfoAndNarrow` wire but Hamlib hard-codes
        // the flag to `1` regardless of bandwidth-on state. Same wire
        // as FTDX-101 from our API's perspective. Hamlib newcat.c:9207.
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ft891)

        let expected = "SH0102;".data(using: .ascii)!
        await transport.setResponse(for: expected, response: expected)

        try await proto.setIFFilter(.filter3)   // narrow

        let cmd = String(data: await transport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH0102;")
    }

    @Test func setIFFilterEmitsZeroWithoutQualifierForFT2000Family() async throws {
        // FT-2000 / FTDX-3000 use `SH0%02d;` — zero always in the
        // qualifier slot, no per-VFO addressing. Hamlib newcat.c:9210.
        // Wire is identical to `.qualifierOnly` when addressing VFO 0.
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ft2000Family)

        let expected = "SH005;".data(using: .ascii)!
        await transport.setResponse(for: expected, response: expected)

        try await proto.setIFFilter(.filter2)   // medium

        let cmd = String(data: await transport.recordedWrites[0], encoding: .ascii)
        #expect(cmd == "SH005;")
    }

    @Test func getIFFilterParsesNarrowFlagResponse() async throws {
        // FTDX-101 responses are 7-char `SH01nn;` where the last two
        // digits are the high-cut code. Prior to the v1.2.2 fix the
        // parser expected 6-char `SH0nn;` and slice-decoded the wrong
        // bytes on FTDX-101.
        let (transport, proto) = try await makeYaesuProtocol(quirks: .ftdx101Family)

        let query = "SH0;".data(using: .ascii)!
        // Radio replies with narrow=1 + code 02 (narrow).
        let response = "SH0102;".data(using: .ascii)!
        await transport.setResponse(for: query, response: response)

        let filter = try await proto.getIFFilter()
        #expect(filter == .filter3)   // narrow (code 2)
    }

    @Test func setRITEmitsRCPreludeThenUnsignedRUForPositiveOffset() async throws {
        // Per Hamlib newcat.c:2930-2936:
        //   SNPRINTF(..., "RC%cRU%04ld%c", cat_term, labs(rit), cat_term);
        // Prior code emitted RU%+05d (signed 5-digit with '+' sign
        // character) which real newcat radios reject. Fixed to
        // unsigned 4-digit with RC; prelude.
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let rcCmd = "RC;".data(using: .ascii)!
        let ruCmd = "RU0100;".data(using: .ascii)!
        let rtCmd = "RT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: rcCmd, response: rcCmd)
        await mockTransport.setResponse(for: ruCmd, response: ruCmd)
        await mockTransport.setResponse(for: rtCmd, response: rtCmd)

        try await yaesuProtocol.setRIT(RITXITState(enabled: true, offset: 100))

        let writes = await mockTransport.recordedWrites
        #expect(writes.count == 3)
        #expect(String(data: writes[0], encoding: .ascii) == "RC;")
        #expect(String(data: writes[1], encoding: .ascii) == "RU0100;")
        #expect(String(data: writes[2], encoding: .ascii) == "RT1;")
    }

    @Test func setRITEmitsRDForNegativeOffsetUnsigned() async throws {
        // Negative offset uses RD (down) with absolute value.
        try await yaesuProtocol.connect()
        await mockTransport.reset()

        let rcCmd = "RC;".data(using: .ascii)!
        let rdCmd = "RD0250;".data(using: .ascii)!
        let rtCmd = "RT1;".data(using: .ascii)!
        await mockTransport.setResponse(for: rcCmd, response: rcCmd)
        await mockTransport.setResponse(for: rdCmd, response: rdCmd)
        await mockTransport.setResponse(for: rtCmd, response: rtCmd)

        try await yaesuProtocol.setRIT(RITXITState(enabled: true, offset: -250))

        let writes = await mockTransport.recordedWrites
        #expect(String(data: writes[1], encoding: .ascii) == "RD0250;")
    }
}
