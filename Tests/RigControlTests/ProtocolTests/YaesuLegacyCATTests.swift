import Foundation
import Testing
@testable import RigControl

/// Byte-level protocol tests for the pre-newcat Yaesu HF flagships:
/// ``YaesuFT1000MPCAT`` and ``YaesuFT847CAT``.
///
/// Every fixture is derived from Hamlib `rigs/yaesu/ft1000mp.c` and
/// `rigs/yaesu/ft847.c`. Fire-and-forget writes for both families —
/// no ACK expected after set commands.
@Suite struct YaesuLegacyCATTests {

    // MARK: - FT-1000MP setup

    private func makeFT1000MP() async throws -> (MockTransport, YaesuFT1000MPCAT) {
        let transport = MockTransport()
        let proto = YaesuFT1000MPCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        return (transport, proto)
    }

    // MARK: - FT-1000MP little-endian BCD

    @Test func ft1000mpEncodesLittleEndianBCD() {
        // 14_230_000 Hz / 10 = 1_423_000 units. Digits low-to-high:
        //   0, 0, 0, 3, 2, 4, 1, 0
        // Little-endian BCD packs digit1<<4 | digit0 into each byte:
        //   byte 0: (0<<4) | 0 = 0x00
        //   byte 1: (3<<4) | 0 = 0x30
        //   byte 2: (4<<4) | 2 = 0x42
        //   byte 3: (0<<4) | 1 = 0x01
        let bytes = YaesuBinaryFrame.encodeBCDLittleEndian8(1_423_000)
        #expect(bytes == [0x00, 0x30, 0x42, 0x01])
    }

    @Test func ft1000mpBCDRoundTripsRepresentativeValues() throws {
        for value: UInt64 in [0, 1, 100, 1_000_000, 12_345_678, 99_999_999] {
            let encoded = YaesuBinaryFrame.encodeBCDLittleEndian8(value)
            let decoded = try YaesuBinaryFrame.decodeBCDLittleEndian8(Data(encoded)[0..<4])
            #expect(decoded == value)
        }
    }

    // MARK: - FT-1000MP frequency

    @Test func ft1000mpSetFrequencyVFOAEmitsLittleEndianFrame() async throws {
        // Reference: Hamlib ft1000mp.c set_freq → to_bcd(...) + opcode 0x0A.
        // For 14_230_000 Hz: 00 30 42 01 0A.
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == Data([0x00, 0x30, 0x42, 0x01, 0x0A]))
    }

    @Test func ft1000mpSetFrequencyVFOBUsesOpcode8A() async throws {
        // VFO B uses opcode 0x8A per ncmd entry 13.
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setFrequency(14_230_000, vfo: .b)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x30, 0x42, 0x01, 0x8A]))
    }

    @Test func ft1000mpFireAndForgetSetFrequencyDoesNotRead() async throws {
        // The FT-1000MP has no ACK read after a set command. If the
        // implementation accidentally reads, this test would hang or
        // fail — the point is that setFrequency returns without
        // consuming a response.
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setFrequency(14_230_000, vfo: .a)

        // No response was set up; the implementation must not have
        // tried to read one.
        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
    }

    // MARK: - FT-1000MP mode

    @Test func ft1000mpSetModeLSBOnVFOA() async throws {
        // Reference: ncmd entry 14 "vfo A mode set LSB":
        //   [0x00, 0x00, 0x00, 0x00, 0x0C].
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setMode(.lsb, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x0C]))
    }

    @Test func ft1000mpSetModeUSBOnVFOA() async throws {
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setMode(.usb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x0C]))
    }

    @Test func ft1000mpSetModeAMOnVFOA() async throws {
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setMode(.am, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x04, 0x0C]))
    }

    @Test func ft1000mpSetModeLSBOnVFOBSetsHighBit() async throws {
        // Reference: ncmd entry 26 "vfo B mode set LSB":
        //   [0x00, 0x00, 0x00, 0x80, 0x0C].
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setMode(.lsb, vfo: .b)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x80, 0x0C]))
    }

    @Test func ft1000mpSetModeRTTYOnVFOA() async throws {
        // ncmd entry 22 "vfo A mode set RTTY-LSB":
        //   [0x00, 0x00, 0x00, 0x08, 0x0C].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setMode(.rtty, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x08, 0x0C]))
    }

    // MARK: - FT-1000MP PTT + VFO

    @Test func ft1000mpSetPTTOn() async throws {
        // ncmd entry 40: [_,_,_,0x01,0x0F].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setPTT(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x0F]))
    }

    @Test func ft1000mpSetPTTOff() async throws {
        // ncmd entry 39: [_,_,_,0x00,0x0F].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setPTT(false)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x0F]))
    }

    @Test func ft1000mpSelectVFOAEmitsExpectedFrame() async throws {
        // ncmd entry 4: [_,_,_,0x00,0x05].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.selectVFO(.a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x05]))
    }

    @Test func ft1000mpSelectVFOB() async throws {
        // ncmd entry 5: [_,_,_,0x01,0x05].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.selectVFO(.b)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x05]))
    }

    @Test func ft1000mpReadsBothVFOFrequenciesFromStatus() async throws {
        let (transport, proto) = try await makeFT1000MP()
        var status = [UInt8](repeating: 0, count: 32)
        // 14,230,000 * 16 / 10 = 0x015B6980.
        status.replaceSubrange(1...4, with: [0x01, 0x5B, 0x69, 0x80])
        // 7,074,000 * 16 / 10 = 0x00ACB480.
        status.replaceSubrange(17...20, with: [0x00, 0xAC, 0xB4, 0x80])
        let query = Data([0x00, 0x00, 0x00, 0x03, 0x10])
        await transport.setResponse(for: query, response: Data(status))

        #expect(try await proto.getFrequency(vfo: .a) == 14_230_000)
        #expect(try await proto.getFrequency(vfo: .b) == 7_074_000)
    }

    @Test func ft1000mpReadsModeAndExtensionFlag() async throws {
        let (transport, proto) = try await makeFT1000MP()
        var status = [UInt8](repeating: 0, count: 32)
        status[7] = 0x02
        status[8] = 0x80       // CW with extension = CW (USB)
        status[23] = 0x05
        status[24] = 0x80      // RTTY with extension = RTTY-R
        let query = Data([0x00, 0x00, 0x00, 0x03, 0x10])
        await transport.setResponse(for: query, response: Data(status))

        #expect(try await proto.getMode(vfo: .a) == .cw)
        #expect(try await proto.getMode(vfo: .b) == .rttyR)
    }

    @Test func ft1000mpModeSettersMatchHamlibDirection() throws {
        #expect(try YaesuFT1000MPCAT.modeSelector(for: .cw, vfo: .a) == 0x03)
        #expect(try YaesuFT1000MPCAT.modeSelector(for: .cwR, vfo: .a) == 0x02)
        #expect(try YaesuFT1000MPCAT.modeSelector(for: .dataUSB, vfo: .a) == 0x09)
        #expect(try YaesuFT1000MPCAT.modeSelector(for: .dataFM, vfo: .b) == 0x8B)
    }

    @Test func ft1000mpSplitUsesFlagsStatus() async throws {
        let (transport, proto) = try await makeFT1000MP()
        let query = Data([0x00, 0x00, 0x00, 0x00, 0xFA])
        await transport.setResponse(for: query, response: Data([0x01, 0, 0, 0, 0]))

        try await proto.setSplit(true)
        #expect(try await proto.getSplit())
        #expect(await transport.recordedWrites.contains(
            Data([0x00, 0x00, 0x00, 0x01, 0x01])
        ))
    }

    @Test func ft1000mpPTTReadRemainsExplicitlyUnsupported() async throws {
        let (_, proto) = try await makeFT1000MP()
        await #expect(throws: RigError.self) { _ = try await proto.getPTT() }
    }

    @Test func ft1000mpSetsRITAndXITUsingClarifierFrames() async throws {
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setRIT(RITXITState(enabled: true, offset: 1_230))
        try await proto.setXIT(RITXITState(enabled: true, offset: -450))

        #expect(await transport.recordedWrites == [
            Data([0x00, 0x00, 0x00, 0x01, 0x09]),
            Data([0x23, 0x01, 0x00, 0xFF, 0x09]),
            Data([0x00, 0x00, 0x00, 0x81, 0x09]),
            Data([0x45, 0x00, 0xFF, 0xFF, 0x09]),
        ])
    }

    @Test func ft1000mpReadsIndependentClarifierEnableBits() async throws {
        let (transport, proto) = try await makeFT1000MP()
        var status = [UInt8](repeating: 0, count: 32)
        status[5] = 0x03
        status[6] = 0x20 // 800 native units × 10/16 = +500 Hz
        status[9] = 0x02 // RIT on, XIT off
        let query = Data([0x00, 0x00, 0x00, 0x03, 0x10])
        await transport.setResponse(for: query, response: Data(status))

        #expect(try await proto.getRIT() == RITXITState(enabled: true, offset: 500))
        #expect(try await proto.getXIT() == RITXITState(enabled: false, offset: 500))
    }

    @Test func ft1000mpRejectsOutOfRangeClarifierOffset() async throws {
        let (_, proto) = try await makeFT1000MP()
        await #expect(throws: RigError.self) {
            try await proto.setRIT(RITXITState(enabled: true, offset: 10_000))
        }
    }

    @Test func ft1000mpDoesNotOverclaimRFPowerSetSupport() {
        #expect(!RadioCapabilitiesDatabase.Yaesu.ft1000MP.powerControl)
        #expect(RadioCapabilitiesDatabase.Yaesu.ft1000MP.supportsSignalStrength)
        #expect(RadioCapabilitiesDatabase.Yaesu.ft1000MP.supportsRFPowerMeter)
        #expect(RadioCapabilitiesDatabase.Yaesu.ft1000MP.supportsSWRMeter)
        #expect(RadioCapabilitiesDatabase.Yaesu.ft1000MP.supportsALCMeter)
        #expect(RadioCapabilitiesDatabase.Yaesu.ft1000MP.supportsCompMeter)
    }

    @Test func ft1000mpVariantsUseCorrectRatedPowerCapabilities() async throws {
        #expect(RadioDefinition.Yaesu.ft1000MP.capabilities.maxPower == 100)
        #expect(RadioDefinition.Yaesu.ft1000MPMkV.capabilities.maxPower == 200)
        #expect(RadioDefinition.Yaesu.ft1000MPMkVField.capabilities.maxPower == 100)

        let mkVProtocol = try #require(
            RadioDefinition.Yaesu.ft1000MPMkV.createProtocol(transport: MockTransport())
                as? YaesuFT1000MPCAT
        )
        let fieldProtocol = try #require(
            RadioDefinition.Yaesu.ft1000MPMkVField.createProtocol(transport: MockTransport())
                as? YaesuFT1000MPCAT
        )
        #expect(await mkVProtocol.capabilities.maxPower == 200)
        #expect(await fieldProtocol.capabilities.maxPower == 100)
    }

    @Test func ft1000mpSignalStrengthUsesHamlibCalibration() async throws {
        let (transport, proto) = try await makeFT1000MP()
        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        await transport.setResponse(for: query, response: Data([160, 0, 0, 0, 0]))
        #expect(try await proto.getSignalStrength() == SignalStrength(sUnits: 9, raw: 160))

        await transport.setResponse(for: query, response: Data([255, 0, 0, 0, 0]))
        #expect(try await proto.getSignalStrength() == SignalStrength(sUnits: 9, overS9: 60, raw: 255))
    }

    @Test(arguments: [
        (UInt8(0x80), MeterReading.Kind.rfPower),
        (UInt8(0x81), MeterReading.Kind.alc),
        (UInt8(0x83), MeterReading.Kind.comp),
        (UInt8(0x85), MeterReading.Kind.swr),
    ])
    func ft1000mpReadsTXMeters(selector: UInt8,
                               kind: MeterReading.Kind) async throws {
        let (transport, proto) = try await makeFT1000MP()
        let query = Data([selector, selector, selector, selector, 0xF7])
        await transport.setResponse(for: query, response: Data([128, 0, 0, 0, 0]))

        let reading: MeterReading
        switch kind {
        case .rfPower: reading = try await proto.getRFPowerOut()
        case .alc: reading = try await proto.getALC()
        case .comp: reading = try await proto.getComp()
        case .swr: reading = try await proto.getSWR()
        default: throw RigError.invalidResponse
        }
        #expect(reading.kind == kind)
        #expect(reading.raw == 128)
        #expect(abs(reading.normalized - 128.0 / 255.0) < 0.000_001)
    }

    @Test func ft920RejectsFT1000OnlyMeters() async throws {
        let transport = MockTransport()
        let proto = YaesuFT1000MPCAT(transport: transport, capabilities: .full, family: .ft920)
        try await proto.connect()
        await #expect(throws: RigError.self) { _ = try await proto.getSignalStrength() }
        await #expect(throws: RigError.self) { _ = try await proto.getALC() }
    }

    // MARK: - FT-847 setup

    private func makeFT847(unidirectional: Bool = false)
        async throws -> (MockTransport, YaesuFT847CAT)
    {
        let transport = MockTransport()
        let proto = YaesuFT847CAT(
            transport: transport,
            capabilities: RadioCapabilitiesDatabase.Yaesu.ft847,
            isUnidirectional: unidirectional
        )
        try await proto.connect()
        return (transport, proto)
    }

    @Test func ft847CapabilitiesMatchImplementedTraits() async throws {
        let (_, proto) = try await makeFT847()
        // Compile-time conformance checks; these fail to build if a trait is dropped.
        let _: any SupportsSplit = proto
        let _: any SupportsSignalStrength = proto
        let _: any SupportsTXMeters = proto
        #expect(!RadioCapabilitiesDatabase.Yaesu.ft847.powerControl)
        #expect(RadioCapabilitiesDatabase.Yaesu.ft847.supportsALCMeter)
    }

    // MARK: - FT-847 frequency

    @Test func ft847SetFrequencyEmitsBigEndianBCDFrame() async throws {
        // Reference: Hamlib ft847.c set_freq → to_bcd_be + opcode 0x01.
        // For 14_230_000 Hz: 01 42 30 00 01 (same as FT-817 — both
        // are big-endian).
        let (transport, proto) = try await makeFT847()

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func ft847SetFrequencyIsFireAndForget() async throws {
        // Contrast with FT-817 which reads an ACK; FT-847 does not.
        // Not consuming a response is the whole safety win of the
        // dedicated adapter.
        let (transport, proto) = try await makeFT847()
        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
    }

    @Test func ft847ReadsFrequencyFromCombinedStatusFrame() async throws {
        let (transport, proto) = try await makeFT847()
        let query = Data([0x00, 0x00, 0x00, 0x00, 0x03])
        await transport.setResponse(
            for: query,
            response: Data([0x01, 0x42, 0x30, 0x00, 0x01])
        )

        #expect(try await proto.getFrequency(vfo: .a) == 14_230_000)
    }

    // MARK: - FT-847 mode

    @Test func ft847SetModeLSB() async throws {
        // ncmd table entry: [0x00, 0x00, 0x00, 0x00, 0x07].
        let (transport, proto) = try await makeFT847()
        try await proto.setMode(.lsb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func ft847SetModeUSB() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setMode(.usb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func ft847SetModeFMNarrow() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setMode(.fmN, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x88, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func ft847ReadsModeFromCombinedStatusFrame() async throws {
        let (transport, proto) = try await makeFT847()
        let query = Data([0x00, 0x00, 0x00, 0x00, 0x03])
        await transport.setResponse(
            for: query,
            response: Data([0x01, 0x42, 0x30, 0x00, 0x88])
        )

        #expect(try await proto.getMode(vfo: .a) == .fmN)
    }

    @Test func ft847SatelliteModeRoutesModeToRxAndTxVFOs() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setSplit(true)
        try await proto.setMode(.usb, vfo: .a)
        try await proto.setMode(.fm, vfo: .b)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x4E]))
        #expect(writes[1] == Data([0x01, 0x00, 0x00, 0x00, 0x17]))
        #expect(writes[2] == Data([0x08, 0x00, 0x00, 0x00, 0x27]))
        #expect(try await proto.getSplit())
    }

    // MARK: - FT-847 PTT

    @Test func ft847SetPTTOn() async throws {
        // ncmd: [0x00, 0x00, 0x00, 0x00, 0x08].
        let (transport, proto) = try await makeFT847()
        try await proto.setPTT(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x08]))
    }

    @Test func ft847SetPTTOffUsesUnusualP4Byte() async throws {
        // ncmd entry: [0x00, 0x00, 0x00, 0x01, 0x88]. The P4 = 0x01
        // is unusual — it's the only PTT command in the Yaesu binary
        // families that doesn't have all zeros in the parameter bytes.
        let (transport, proto) = try await makeFT847()
        try await proto.setPTT(false)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x88]))
    }

    // MARK: - FT-847 satellite mode

    @Test func ft847SatelliteModeEnableEmitsOpcode4E() async throws {
        // ncmd: [0x00, 0x00, 0x00, 0x00, 0x4E] = sat mode on.
        let (transport, proto) = try await makeFT847()
        try await proto.setSatelliteMode(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x4E]))
        #expect(await proto.isSatelliteModeEnabled == true)
    }

    @Test func ft847SatelliteModeDisableEmitsOpcode8E() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setSatelliteMode(true)
        try await proto.setSatelliteMode(false)
        let writes = await transport.recordedWrites
        #expect(writes.count == 2)
        #expect(writes[1] == Data([0x00, 0x00, 0x00, 0x00, 0x8E]))
        #expect(await proto.isSatelliteModeEnabled == false)
    }

    @Test func ft847SatelliteModeChangesSetFrequencyOpcode() async throws {
        // In sat mode, setFrequency(...vfo: .a) uses opcode 0x11
        // (SAT RX). setFrequency(...vfo: .b) uses 0x21 (SAT TX).
        let (transport, proto) = try await makeFT847()

        try await proto.setSatelliteMode(true)
        try await proto.setFrequency(146_500_000, vfo: .a)
        try await proto.setFrequency(437_000_000, vfo: .b)

        let writes = await transport.recordedWrites
        // Index 0: sat mode on. Index 1: SAT RX at 146.5 MHz.
        // Index 2: SAT TX at 437 MHz.
        // 146_500_000 / 10 = 14_650_000 → big-endian BCD:
        //   digits high-to-low: 1,4,6,5,0,0,0,0 → 0x14 0x65 0x00 0x00
        #expect(writes[1] == Data([0x14, 0x65, 0x00, 0x00, 0x11]))
        // 437_000_000 / 10 = 43_700_000 → 0x43 0x70 0x00 0x00
        #expect(writes[2] == Data([0x43, 0x70, 0x00, 0x00, 0x21]))
    }

    // MARK: - FT-847 unidirectional variant

    @Test func ft847UnidirectionalSetsStillEmitBytes() async throws {
        // FT-847UNI writes go on the wire — the radio just doesn't
        // respond. Only reads are affected.
        let (transport, proto) = try await makeFT847(unidirectional: true)

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func ft847UnidirectionalGetFrequencyThrows() async throws {
        let (_, proto) = try await makeFT847(unidirectional: true)

        await #expect(throws: RigError.self) {
            _ = try await proto.getFrequency(vfo: .a)
        }
    }

    @Test func ft847UnidirectionalGetPTTThrows() async throws {
        let (_, proto) = try await makeFT847(unidirectional: true)

        await #expect(throws: RigError.self) {
            _ = try await proto.getPTT()
        }
    }

    // MARK: - FT-847 getPTT polarity (v1.2.0 audit fix)

    @Test func ft847GetPTTBit7SetMeansPTTOff() async throws {
        // Per Hamlib ft847_get_ptt() (ft847.c line 1673):
        //   *ptt = (p->tx_status & 0x80) ? RIG_PTT_OFF : RIG_PTT_ON;
        // Prior to v1.2.0 Swift had this inverted. Regression test.
        let (transport, proto) = try await makeFT847()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        // 0xFF = bit 7 set = radio idle / RX per Hamlib.
        await transport.setResponse(for: query, response: Data([0xFF]))

        let ptt = try await proto.getPTT()
        #expect(ptt == false)
    }

    @Test func ft847GetPTTBit7ClearMeansPTTOn() async throws {
        let (transport, proto) = try await makeFT847()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        // 0x50 = bit 7 clear = radio TXing per Hamlib.
        await transport.setResponse(for: query, response: Data([0x50]))

        let ptt = try await proto.getPTT()
        #expect(ptt == true)
    }

    @Test func ft847SignalStrengthUsesRxStatusDots() async throws {
        let (transport, proto) = try await makeFT847()
        let query = Data([0x00, 0x00, 0x00, 0x00, 0xE7])
        await transport.setResponse(for: query, response: Data([0x1F]))

        let strength = try await proto.getSignalStrength()
        #expect(strength.sUnits == 9)
        #expect(strength.overS9 == 60)
        #expect(strength.raw == 0x1F)
    }

    @Test func ft847ALCUsesTxStatusLowFiveBits() async throws {
        let (transport, proto) = try await makeFT847()
        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        await transport.setResponse(for: query, response: Data([0x90]))

        let alc = try await proto.getALC()
        #expect(alc.kind == .alc)
        #expect(alc.raw == 16)
        #expect(alc.normalized == 16.0 / 31.0)
    }
}
